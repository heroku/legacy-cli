require "heroku/client/cisaurus"
require "heroku/command/base"

module Heroku::Command

  # clone an existing app
  #
  class Fork < Base

    # fork [NEWNAME]
    #
    # Fork an existing app -- copy config vars and Heroku Postgres data, and re-provision add-ons to a new app.
    # New app name should not be an existing app. The new app will be created as part of the forking process.
    #
    # -s, --stack  STACK   # specify a stack for the new app
    # --region REGION      # specify a region
    #
    def index
      options[:ignore_no_org] = true

      from = app
      to = shift_argument || "#{from}-#{(rand*1000).to_i}"
      if from == to
        raise Heroku::Command::CommandFailed.new("Cannot fork to the same app.")
      end

      from_info = api.get_app(from).body

      to_info = action("Creating fork #{to}", :org => !!org) do
        params = {
          "name"    => to,
          "region"  => options[:region] || from_info["region"],
          "stack"   => options[:stack] || from_info["stack"],
          "tier"    => from_info["tier"] == "legacy" ? "production" : from_info["tier"]
        }

        info = if org
          org_api.post_app(params, org).body
        else
          api.post_app(params).body
        end
      end

      action("Copying slug") do
        job_location = cisaurus_client.copy_slug(from, to)
        loop do
          break if cisaurus_client.job_done?(job_location)
          sleep 1
        end
      end

      from_config = api.get_config_vars(from).body
      from_addons = api.get_addons(from).body

      from_addons.each do |addon|
        print "Adding #{addon["name"]}... "
        begin
          to_addon = api.post_addon(to, addon["name"]).body
          puts "done"
        rescue Heroku::API::Errors::RequestFailed => ex
          puts "skipped (%s)" % json_decode(ex.response.body)["error"]
        rescue Heroku::API::Errors::NotFound
          puts "skipped (not found)"
        end
        if addon["name"] =~ /^heroku-postgresql:/
          from_var_name = "#{addon["attachment_name"]}_URL"
          from_attachment = to_addon["message"].match(/Attached as (\w+)_URL\n/)[1]
          if from_config[from_var_name] == from_config["DATABASE_URL"]
            from_config["DATABASE_URL"] = api.get_config_vars(to).body["#{from_attachment}_URL"]
          end
          from_config.delete(from_var_name)

          plan = addon["name"].split(":").last
          unless %w(dev basic hobby-dev hobby-basic).include? plan
            wait_for_db to, to_addon
          end

          check_for_pgbackups! from
          check_for_pgbackups! to
          migrate_db addon, from, to_addon, to
        end
      end

      to_config = api.get_config_vars(to).body

      action("Copying config vars") do
        diff = from_config.inject({}) do |ax, (key, val)|
          ax[key] = val unless to_config[key]
          ax
        end
        api.put_config_vars to, diff
      end

      puts "Fork complete, view it at #{to_info['web_url']}"
    rescue Exception => e
      raise if e.is_a?(Heroku::Command::CommandFailed)

      puts "Failed to fork app #{from} to #{to}."
      message = "WARNING: Potentially Destructive Action\nThis command will destroy #{to} (including all add-ons)."

      if confirm_command(to, message)
        action("Deleting #{to}") do
          begin
            api.delete_app(to)
          rescue Heroku::API::Errors::NotFound
          end
        end
      end
      puts "Original exception below:"
      raise e
    end

  private

    def cisaurus_client
      cisaurus_url = ENV["CISAURUS_HOST"] || "https://cisaurus.herokuapp.com"
      @cisaurus_client ||= Heroku::Client::Cisaurus.new(cisaurus_url)
    end

    def check_for_pgbackups!(app)
      unless api.get_addons(app).body.detect { |addon| addon["name"] =~ /^pgbackups:/ }
        action("Adding pgbackups:plus to #{app}") do
          api.post_addon app, "pgbackups:plus"
        end
      end
    end

    def migrate_db(from_addon, from, to_addon, to)
      transfer = nil

      action("Transferring database (this can take some time)") do
        from_config = api.get_config_vars(from).body
        from_attachment = from_addon["attachment_name"]
        to_config = api.get_config_vars(to).body
        to_attachment = to_addon["message"].match(/Attached as (\w+)_URL\n/)[1]

        pgb = Heroku::Client::Pgbackups.new(from_config["PGBACKUPS_URL"])
        transfer = pgb.create_transfer(
          from_config["#{from_attachment}_URL"],
          from_attachment,
          to_config["#{to_attachment}_URL"],
          to_attachment,
          :expire => "true")

        error transfer["errors"].values.flatten.join("\n") if transfer["errors"]
        loop do
          transfer = pgb.get_transfer(transfer["id"])
          error transfer["errors"].values.flatten.join("\n") if transfer["errors"]
          break if transfer["finished_at"]
          sleep 1
        end
        print " "
      end
    end

    def pg_api
      host = "postgres-api.heroku.com"
      RestClient::Resource.new "https://#{host}/client/v11/databases", Heroku::Auth.user, Heroku::Auth.password
    end

    def wait_for_db(app, attachment)
      attachments = api.get_attachments(app).body.inject({}) { |ax,att| ax.update(att["name"] => att["resource"]["name"]) }
      attachment_name = attachment["message"].match(/Attached as (\w+)_URL\n/)[1]
      action("Waiting for database to be ready (this can take some time)") do
        loop do
          begin
            waiting = json_decode(pg_api["#{attachments[attachment_name]}/wait_status"].get.to_s)["waiting?"]
            break unless waiting
            sleep 5
          rescue RestClient::ResourceNotFound
          rescue Interrupt
            exit 0
          end
        end
        print " "
      end
    end

  end
end
