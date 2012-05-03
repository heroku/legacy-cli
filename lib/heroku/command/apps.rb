require "heroku/command/base"

# manage apps (create, destroy)
#
class Heroku::Command::Apps < Heroku::Command::Base

  # apps
  #
  # list your apps
  #
  def index
    validate_arguments!
    apps = api.get_apps.body
    if apps.length > 0
      apps_by_owner = Hash.new {|hash,key| hash[key] = []}
      apps.each do |app|
        apps_by_owner[app["owner_email"]] << app["name"]
      end
      ([heroku.user] + (apps_by_owner.keys.sort - [heroku.user])).each do |owner|
        unless (apps = apps_by_owner[owner]).empty?
          styled_header("#{owner} Apps")
          styled_array(apps)
        end
      end
    else
      display("You have no apps.")
    end
  end

  alias_command "list", "apps"

  # apps:info
  #
  # show detailed app information
  #
  # -r, --raw  # output info as raw key/value pairs
  #
  def info
    validate_arguments!
    app_data = api.get_app(app).body

    unless options[:raw]
      styled_header(app)
    end

    addons_data = api.get_addons(app).body.map {|addon| addon["description"]}.sort
    collaborators_data = api.get_collaborators(app).body.map {|collaborator| collaborator["email"]}.sort
    collaborators_data.reject! {|email| email == app_data["owner_email"]}
    domain_name = (domains_data = api.get_domains(app).body) && domains_data.first && domains_data.first["domain"]

    if options[:raw]
      if domain_name
        app_data["domain_name"] = domain_name
      end
      app_data.keys.sort_by { |a| a.to_s }.each do |key|
        case key
        when :addons then
          hputs("addons=#{addons_data.join(",")}")
        when :collaborators then
          hputs("collaborators=#{collaborators_data.join(",")}")
        else
          hputs("#{key}=#{app_data[key]}")
        end
      end
    else
      data = app_data.reject do |key, value|
        !["owner_email", "stack"].include?(key)
      end

      data["addons"] = addons_data
      data["collaborators"] = collaborators_data

      if app_data["create_status"] && app_data["create_status"] != "complete"
        data["create_status"] = app_data["create_status"]
      end

      ["cron_finished_at", "cron_next_run"].each do |key|
        if value = app_data[key]
          data[key] = format_date(value)
        end
      end

      ["database_size", "repo_size", "slug_size"].each do |key|
        if value = app_data[key]
          data[key] = format_bytes(value)
        end
      end

      ["git_url", "web_url"].each do |key|
        upcased_key = key.to_s.gsub("url","URL").to_sym
        data[upcased_key] = app_data[key]
      end

      if data["stack"] != "cedar"
        data.merge!("dynos" => app_data["dynos"], "workers" => app_data["workers"])
      end

      if app_data["database_tables"]
        data["Database Size"].gsub!('(empty)', '0K') + " in #{quantify("table", app_data["database_tables"])}"
      end

      if app_data["dyno_hours"].is_a?(Hash)
        data["Dyno Hours"] = app_data["dyno_hours"].keys.map do |type|
          "%s - %0.2f dyno-hours" % [ type.to_s.capitalize, app_data["dyno_hours"][type] ]
        end
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
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  # -s, --stack STACK          # the stack on which to create the app
  #
  def create
    validate_arguments!
    remote  = extract_option('--remote', 'heroku')
    stack   = extract_option('--stack', 'aspen-mri-1.8.6')
    timeout = extract_option('--timeout', 30).to_i
    name    = args.shift.downcase.strip rescue nil
    info    = api.post_app({ "name" => name, "stack" => stack }).body
    hprint("Creating #{info["name"]}...")
    begin
      if info["create_status"] == "creating"
        Timeout::timeout(timeout) do
          loop do
            break if heroku.create_complete?(info["name"])
            hprint(".")
            sleep 1
          end
        end
      end
      hputs(" done, stack is #{info["stack"]}")

      (options[:addons] || "").split(",").each do |addon|
        addon.strip!
        hprint("Adding #{addon} to #{info["name"]}... ")
        api.post_addon(name, addon)
        hputs("done")
      end

      if buildpack = options[:buildpack]
        api.put_config_vars(name, "BUILDPACK_URL" => buildpack)
        display("BUILDPACK_URL=#{buildpack}")
      end

      hputs([ info["web_url"], info["git_url"] ].join(" | "))
    rescue Timeout::Error
      hputs("Timed Out! Check heroku status for known issues.")
    end

    create_git_remote(remote || "heroku", info["git_url"])
  end

  alias_command "create", "apps:create"

  # apps:rename NEWNAME
  #
  # rename the app
  #
  def rename
    validate_arguments!
    newname = args.shift.downcase.strip rescue ''
    raise(Heroku::Command::CommandFailed, "Must specify a new name.") if newname == ''

    api.put_app(app, "name" => newname)

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
  def open
    validate_arguments!
    app_data = api.get_app(app).body
    url = app_data["web_url"]
    hputs("Opening #{url}")
    Launchy.open url
  end

  alias_command "open", "apps:open"

  # apps:destroy
  #
  # permanently destroy an app
  #
  def destroy
    validate_arguments!
    @app = args.first || options[:app] || options[:confirm]
    unless @app
      raise Heroku::Command::CommandFailed.new("Usage: heroku apps:destroy --app APP")
    end

    api.get_app(app) # fail fast if no access or doesn't exist

    message = "WARNING: Potentially Destructive Action\nThis command will destroy #{app} (including all add-ons)."
    if confirm_command(app, message)
      hprint "Destroying #{app} (including all add-ons)... "
      api.delete_app(app)
      if remotes = git_remotes(Dir.pwd)
        remotes.each do |remote_name, remote_app|
          next if app != remote_app
          git "remote rm #{remote_name}"
        end
      end
      hputs("done")
    end
  end

  alias_command "destroy", "apps:destroy"
  alias_command "apps:delete", "apps:destroy"

end
