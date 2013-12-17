require "heroku/command/base"

# manage apps (create, destroy)
#
class Heroku::Command::Apps < Heroku::Command::Base

  # apps
  #
  # list your apps
  #
  # -o, --org ORG  # the org to list the apps for
  # -A, --all      # list all apps in the org. Not just joined apps
  # -p, --personal # list apps in personal account when a default org is set
  #
  #Example:
  #
  # $ heroku apps
  # === My Apps
  # example
  # example2
  #
  # === Collaborated Apps
  # theirapp   other@owner.name
  #
  def index
    validate_arguments!
    options[:ignore_no_org] = true

    apps = if org
      org_api.get_apps(org).body
    else
      api.get_apps.body.select { |app| options[:all] ? true : !org?(app["owner_email"]) }
    end

    unless apps.empty?
      if org
        joined, unjoined = apps.partition { |app| app['joined'] == true }

        styled_header("Apps joined in organization #{org}")
        unless joined.empty?
          styled_array(joined.map {|app| regionized_app_name(app) + (app['locked'] ? ' (locked)' : '') })
        else
          display("You haven't joined any apps.")
          display("Use --all to see unjoined apps.") unless options[:all]
          display
        end

        if options[:all]
          styled_header("Apps available to join in organization #{org}")
          unless unjoined.empty?
            styled_array(unjoined.map {|app| regionized_app_name(app) + (app['locked'] ? ' (locked)' : '') })
          else
            display("There are no apps to join.")
            display
          end
        end
      else
        my_apps, collaborated_apps = apps.partition { |app| app["owner_email"] == Heroku::Auth.user }

        unless my_apps.empty?
          styled_header("My Apps")
          styled_array(my_apps.map { |app| regionized_app_name(app) })
        end

        unless collaborated_apps.empty?
          styled_header("Collaborated Apps")
          styled_array(collaborated_apps.map { |app| [regionized_app_name(app), app_owner(app["owner_email"])] })
        end
      end
    else
      org ? display("There are no apps in organization #{org}.") : display("You have no apps.")
    end
  end

  alias_command "list", "apps"

  # apps:info
  #
  # show detailed app information
  #
  # -s, --shell  # output more shell friendly key/value pairs
  #
  #Examples:
  #
  # $ heroku apps:info
  # === example
  # Git URL:   git@heroku.com:example.git
  # Repo Size: 5M
  # ...
  #
  # $ heroku apps:info --shell
  # git_url=git@heroku.com:example.git
  # repo_size=5000000
  # ...
  #
  def info
    validate_arguments!
    app_data = api.get_app(app).body

    unless options[:shell]
      styled_header(app_data["name"])
    end

    addons_data = api.get_addons(app).body.map {|addon| addon['name']}.sort
    collaborators_data = api.get_collaborators(app).body.map {|collaborator| collaborator["email"]}.sort
    collaborators_data.reject! {|email| email == app_data["owner_email"]}

    if org? app_data['owner_email']
      app_data['owner'] = app_owner(app_data['owner_email'])
      app_data.delete("owner_email")
    end

    if options[:shell]
      if app_data['domain_name']
        app_data['domain_name'] = app_data['domain_name']['domain']
      end
      unless addons_data.empty?
        app_data['addons'] = addons_data.join(',')
      end
      unless collaborators_data.empty?
        app_data['collaborators'] = collaborators_data.join(',')
      end
      app_data.keys.sort_by { |a| a.to_s }.each do |key|
        hputs("#{key}=#{app_data[key]}")
      end
    else
      data = {}

      unless addons_data.empty?
        data["Addons"] = addons_data
      end

      if app_data["archived_at"]
        data["Archived At"] = format_date(app_data["archived_at"])
      end

      data["Collaborators"] = collaborators_data

      if app_data["create_status"] && app_data["create_status"] != "complete"
        data["Create Status"] = app_data["create_status"]
      end

      if app_data["cron_finished_at"]
        data["Cron Finished At"] = format_date(app_data["cron_finished_at"])
      end

      if app_data["cron_next_run"]
        data["Cron Next Run"] = format_date(app_data["cron_next_run"])
      end

      if app_data["database_size"]
        data["Database Size"] = format_bytes(app_data["database_size"])
      end

      data["Git URL"] = app_data["git_url"]

      if app_data["database_tables"]
        data["Database Size"].gsub!('(empty)', '0K') + " in #{quantify("table", app_data["database_tables"])}"
      end

      if app_data["dyno_hours"].is_a?(Hash)
        data["Dyno Hours"] = app_data["dyno_hours"].keys.map do |type|
          "%s - %0.2f dyno-hours" % [ type.to_s.capitalize, app_data["dyno_hours"][type] ]
        end
      end

      data["Owner Email"] = app_data["owner_email"] if app_data["owner_email"]
      data["Owner"] = app_data["owner"] if app_data["owner"]
      data["Region"] = app_data["region"] if app_data["region"]
      data["Repo Size"] = format_bytes(app_data["repo_size"]) if app_data["repo_size"]
      data["Slug Size"] = format_bytes(app_data["slug_size"]) if app_data["slug_size"]
      data["Cache Size"] = format_bytes(app_data["cache_size"]) if app_data["cache_size"]

      data["Stack"] = app_data["stack"]
      if data["Stack"] != "cedar"
        data.merge!("Dynos" => app_data["dynos"], "Workers" => app_data["workers"])
      end

      data["Web URL"] = app_data["web_url"]

      if app_data["tier"]
        data["Tier"] = app_data["tier"].capitalize
      end

      styled_hash(data)
    end
  end

  alias_command "info", "apps:info"

  # apps:create [NAME]
  #
  # create a new app
  #
  #     --addons ADDONS        # a comma-delimited list of addons to install
  # -b, --buildpack BUILDPACK  # a buildpack url to use for this app
  # -n, --no-remote            # don't create a git remote
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  # -s, --stack STACK          # the stack on which to create the app
  #     --region REGION        # specify region for this app to run in
  # -l, --locked               # lock the app
  # -t, --tier TIER            # HIDDEN: the tier for this app
  #
  #Examples:
  #
  # $ heroku apps:create
  # Creating floating-dragon-42... done, stack is cedar
  # http://floating-dragon-42.heroku.com/ | git@heroku.com:floating-dragon-42.git
  #
  # $ heroku apps:create -s bamboo
  # Creating floating-dragon-42... done, stack is bamboo-mri-1.9.2
  # http://floating-dragon-42.herokuapp.com/ | git@heroku.com:floating-dragon-42.git
  #
  # # specify a name
  # $ heroku apps:create example
  # Creating example... done, stack is cedar
  # http://example.heroku.com/ | git@heroku.com:example.git
  #
  # # create a staging app
  # $ heroku apps:create example-staging --remote staging
  #
  # # create an app in the eu region
  # $ heroku apps:create --region eu
  #
  def create
    name    = shift_argument || options[:app] || ENV['HEROKU_APP']
    validate_arguments!
    options[:ignore_no_org] = true

    params = {
      "name" => name,
      "region" => options[:region],
      "stack" => options[:stack],
      "locked" => options[:locked]
    }

    info = if org
      org_api.post_app(params, org).body
    else
      api.post_app(params).body
    end

    begin
      action("Creating #{info['name']}", :org => !!org) do
        if info['create_status'] == 'creating'
          Timeout::timeout(options[:timeout].to_i) do
            loop do
              break if api.get_app(info['name']).body['create_status'] == 'complete'
              sleep 1
            end
          end
        end
        if options[:region]
          status("region is #{region_from_app(info)}")
        else
          status("stack is #{info['stack']}")
        end
      end

      (options[:addons] || "").split(",").each do |addon|
        addon.strip!
        action("Adding #{addon} to #{info["name"]}") do
          api.post_addon(info["name"], addon)
        end
      end

      if buildpack = options[:buildpack]
        api.put_config_vars(info["name"], "BUILDPACK_URL" => buildpack)
        display("BUILDPACK_URL=#{buildpack}")
      end

      hputs([ info["web_url"], info["git_url"] ].join(" | "))
    rescue Timeout::Error
      hputs("Timed Out! Run `heroku status` to check for known platform issues.")
    end

    unless options[:no_remote].is_a? FalseClass
      create_git_remote(options[:remote] || "heroku", info["git_url"])
    end
  end

  alias_command "create", "apps:create"

  # apps:rename NEWNAME
  #
  # rename the app
  #
  #Example:
  #
  # $ heroku apps:rename example-newname
  # http://example-newname.herokuapp.com/ | git@heroku.com:example-newname.git
  # Git remote heroku updated
  #
  def rename
    newname = shift_argument
    if newname.nil? || newname.empty?
      error("Usage: heroku apps:rename NEWNAME\nMust specify NEWNAME to rename.")
    end
    validate_arguments!

    action("Renaming #{app} to #{newname}") do
      api.put_app(app, "name" => newname)
    end

    app_data = api.get_app(newname).body
    hputs([ app_data["web_url"], app_data["git_url"] ].join(" | "))

    if remotes = git_remotes(Dir.pwd)
      remotes.each do |remote_name, remote_app|
        next if remote_app != app
        git "remote rm #{remote_name}"
        git "remote add #{remote_name} #{app_data["git_url"]}"
        hputs("Git remote #{remote_name} updated")
      end
    else
      hputs("Don't forget to update your Git remotes on any local checkouts.")
    end
  end

  alias_command "rename", "apps:rename"

  # apps:open
  #
  # open the app in a web browser
  #
  #Example:
  #
  # $ heroku apps:open
  # Opening example... done
  #
  def open
    path = shift_argument
    validate_arguments!

    app_data = api.get_app(app).body

    url = [app_data['web_url'], path].join
    launchy("Opening #{app}", url)
  end

  alias_command "open", "apps:open"

  # apps:destroy
  #
  # permanently destroy an app
  #
  #Example:
  #
  # $ heroku apps:destroy -a example --confirm example
  # Destroying example (including all add-ons)... done
  #
  def destroy
    @app = shift_argument || options[:app] || options[:confirm]
    validate_arguments!

    unless @app
      error("Usage: heroku apps:destroy --app APP\nMust specify APP to destroy.")
    end

    api.get_app(@app) # fail fast if no access or doesn't exist

    message = "WARNING: Potentially Destructive Action\nThis command will destroy #{@app} (including all add-ons)."
    if confirm_command(@app, message)
      action("Destroying #{@app} (including all add-ons)") do
        api.delete_app(@app)
        if remotes = git_remotes(Dir.pwd)
          remotes.each do |remote_name, remote_app|
            next if @app != remote_app
            git "remote rm #{remote_name}"
          end
        end
      end
    end
  end

  alias_command "destroy", "apps:destroy"
  alias_command "apps:delete", "apps:destroy"

  # apps:join --app APP
  #
  # add yourself to an organization app
  #
  # -a, --app APP  # the app
  def join
    begin
      action("Joining application #{app}") do
        org_api.join_app(app)
      end
    rescue Heroku::API::Errors::NotFound
      error("Application does not exist or does not belong to an org that you have access to.")
    end
  end

  alias_command "join", "apps:join"

  # apps:leave --app APP
  #
  # remove yourself from an organization app
  #
  # -a, --app APP  # the app
  def leave
    begin
      action("Leaving application #{app}") do
        if org_from_app = extract_org_from_app
          org_api.leave_app(app)
        else
          api.delete_collaborator(app, Heroku::Auth.user)
        end
      end
    end
  end

  alias_command "leave", "apps:leave"

  # apps:lock
  #
  # lock an organization app to restrict access
  #
  def lock
    begin
      action("Locking #{app}") {
        org_api.lock_app(app)
      }
      display("Organization members must be invited this app.")
    rescue Excon::Errors::NotFound
      error("#{app} was not found")
    end
  end

  alias_command "lock", "apps:lock"

  # apps:unlock
  #
  # unlock an organization app so that any org member can join it
  #
  def unlock
    begin
      action("Unlocking #{app}") {
        org_api.unlock_app(app)
      }
      display("All organization members can join this app.")
    rescue Excon::Errors::NotFound
      error("#{app} was not found")
    end
  end

  alias_command "unlock", "apps:unlock"

  # apps:upgrade TIER
  #
  # HIDDEN: upgrade an app's pricing tier
  #
  def upgrade
    tier = shift_argument
    error("Usage: heroku apps:upgrade TIER\nMust specify TIER to upgrade.") if tier.nil? || tier.empty?
    validate_arguments!

    action("Upgrading #{app} to #{tier}") do
      api.put_app(app, "tier" => tier)
    end
  end

  alias_command "upgrade", "apps:upgrade"

  # apps:downgrade TIER
  #
  # HIDDEN: downgrade an app's pricing tier
  #
  def downgrade
    tier = shift_argument
    error("Usage: heroku apps:downgrade TIER\nMust specify TIER to downgrade.") if tier.nil? || tier.empty?
    validate_arguments!

    action("Upgrading #{app} to #{tier}") do
      api.put_app(app, "tier" => tier)
    end
  end

  alias_command "downgrade", "apps:downgrade"

  private

  def regionized_app_name(app)
    region = region_from_app(app)

    # temporary, show region for non-us apps
    if app["region"] && region != 'us'
      "#{app["name"]} (#{region})"
    else
      app["name"]
    end
  end

  def region_from_app app
    region = app["region"].is_a?(Hash) ? app["region"]["name"] : app["region"]
  end

end
