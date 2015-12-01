require "heroku/command/base"
require "heroku/command/stack"
require "heroku/api/organizations_apps_v3"

# manage apps (create, destroy)
#
class Heroku::Command::Apps < Heroku::Command::Base

  # apps
  #
  # list your apps
  #
  # -o, --org ORG     # the org to list the apps for
  #     --space SPACE # HIDDEN: list apps in a given space
  # -A, --all         # list all collaborated apps, including joined org apps in personal app list
  # -p, --personal    # list apps in personal account when a default org is set
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

    if options[:space]
      apps.select! do |app|
        app["space"] && [app["space"]["name"], app["space"]["id"]].include?(options[:space])
      end
    end

    unless apps.empty?
      if org
        styled_header(in_message("Apps", app_in_msg_opts))
        styled_array(apps.map {|app| regionized_app_name(app) + (app['locked'] ? ' (locked)' : '') })
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
      if org
        display("#{in_message("There are no apps", app_in_msg_opts)}.")
      else
        display("You have no apps.")
      end
    end
  end

  alias_command "list", "apps"

  # apps:create [NAME]
  #
  # create a new app
  #
  #     --addons ADDONS        # a comma-delimited list of addons to install
  # -b, --buildpack BUILDPACK  # a buildpack url to use for this app
  # -n, --no-remote            # don't create a git remote
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  #     --space SPACE          # HIDDEN: the space in which to create the app
  # -s, --stack STACK          # the stack on which to create the app
  #     --region REGION        # specify region for this app to run in
  # -l, --locked               # lock the app
  #     --ssh-git              # Use SSH git protocol
  # -t, --tier TIER            # HIDDEN: the tier for this app
  #     --http-git             # HIDDEN: Use HTTP git protocol
  # -k, --kernel KERNEL        # HIDDEN: Use a custom platform kernel
  #
  #Examples:
  #
  # $ heroku apps:create
  # Creating floating-dragon-42... done, stack is cedar
  # http://floating-dragon-42.heroku.com/ | https://git.heroku.com/floating-dragon-42.git
  #
  # # specify a stack
  # $ heroku create -s cedar
  # Creating stormy-garden-5052... done, stack is cedar
  # https://stormy-garden-5052.herokuapp.com/ | https://git.heroku.com/stormy-garden-5052.git
  #
  # # specify a name
  # $ heroku apps:create example
  # Creating example... done, stack is cedar
  # http://example.heroku.com/ | https://git.heroku.com/example.git
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
    validate_space_xor_org!

    params = {
      "name" => name,
      "region" => options[:region],
      "space" => options[:space],
      "stack" => Heroku::Command::Stack::Codex.in(options[:stack]),
      "kernel" => options[:kernel],
      "locked" => options[:locked]
    }

    info = if options[:space]
      api.post_organizations_app_v3(params).body
    elsif org
      org_api.post_app(params, org).body
    else
      api.post_app(params).body
    end

    begin
      action("Creating #{info['name']}", app_in_msg_opts) do
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
          stack = (info['stack'].is_a?(Hash) ? info['stack']["name"] : info['stack'])
          status("stack is #{Heroku::Command::Stack::Codex.out(stack)}")
        end
      end

      (options[:addons] || "").split(",").each do |addon|
        addon.strip!
        action("Adding #{addon} to #{info["name"]}") do
          api.post_addon(info["name"], addon)
        end
      end

      if buildpack = options[:buildpack]
        api.put_app_buildpacks_v3(info['name'], {:updates => [{:buildpack => buildpack}]})
        display "Buildpack set. Next release on #{info['name']} will use #{buildpack}."
      end

      hputs([ info["web_url"], git_url(info['name']) ].join(" | "))
    rescue Timeout::Error
      hputs("Timed Out! Run `heroku status` to check for known platform issues.")
    end

    unless options[:no_remote].is_a? FalseClass
      create_git_remote(options[:remote] || "heroku", git_url(info['name']))
    end
  end

  alias_command "create", "apps:create"

  # apps:rename NEWNAME --app APP
  #
  # rename the app
  #
  #     --ssh-git              # Use SSH git protocol
  #     --http-git             # HIDDEN: Use HTTP git protocol
  #
  #Example:
  #
  # $ heroku apps:rename example-newname
  # http://example-newname.herokuapp.com/ | https://git.heroku.com/example-newname.git
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
    hputs([ app_data["web_url"], git_url(newname) ].join(" | "))

    if remotes = git_remotes(Dir.pwd)
      remotes.each do |remote_name, remote_app|
        next if remote_app != app
        git "remote rm #{remote_name}"
        git "remote add #{remote_name} #{git_url(newname)}"
        hputs("Git remote #{remote_name} updated")
      end
    else
      hputs("Don't forget to update your Git remotes on any local checkouts.")
    end
  end

  alias_command "rename", "apps:rename"

  # apps:open --app APP
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

  # apps:destroy --app APP
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

  # apps:lock --app APP
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

  # apps:unlock --app APP
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

  # apps:upgrade TIER --app APP
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

  # apps:downgrade TIER --app APP
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

  def app_in_msg_opts
    display_org = !!org
    if options[:space]
      space_name = options[:space]
      display_org = false
    end
   { :org => display_org, :space => space_name }
  end
end
