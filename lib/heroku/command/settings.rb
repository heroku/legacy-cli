require "heroku/command/base"

# manage optional settings
#
class Heroku::Command::Settings < Heroku::Command::Base

  # labs
  #
  # list experimental settings
  #
  #Example:
  #
  # === User Features (david@heroku.com)
  # [+] dashboard  Use Heroku Dashboard by default
  #
  # === App Features (glacial-retreat-5913)
  # [ ] preboot            Provide seamless web dyno deploys
  # [ ] user-env-compile   Add user config vars to the environment during slug compilation  # $ heroku labs -a example
  #
  def index
    validate_arguments!

    user_settings, app_settings = api.get_features(app).body.sort_by do |setting|
      setting["name"]
    end.partition do |setting|
      setting["kind"] == "user"
    end

    # general availability settings are managed via `settings`, not `labs`
    app_settings.reject! { |f| f["state"] == "general" }

    display_app = app || "no app specified"

    styled_header "User Features (#{Heroku::Auth.user})"
    display_settings user_settings
    display
    styled_header "App Features (#{display_app})"
    display_settings app_settings
  end

  alias_command "labs:list", "labs"

  # labs:info SETTING
  #
  # displays additional information about SETTING
  #
  #Example:
  #
  # $ heroku labs:info user_env_compile
  # === user_env_compile
  # Docs:    http://devcenter.heroku.com/articles/labs-user-env-compile
  # Summary: Add user config vars to the environment during slug compilation
  #
  def info
    unless setting_name = shift_argument
      error("Usage: heroku labs:info SETTING\nMust specify SETTING for info.")
    end
    validate_arguments!

    setting_data = api.get_feature(setting_name, app).body
    styled_header(setting_data['name'])
    styled_hash({
      'Summary' => setting_data['summary'],
      'Docs'    => setting_data['docs']
    })
  end

  # labs:disable SETTING
  #
  # disables an experimental setting
  #
  #Example:
  #
  # $ heroku labs:disable ninja-power
  # Disabling ninja-power setting for me@example.org... done
  #
  def disable
    setting_name = shift_argument
    error "Usage: heroku labs:disable SETTING\nMust specify SETTING to disable." unless setting_name
    validate_arguments!

    setting = api.get_features(app).body.detect { |f| f["name"] == setting_name }
    message = "Disabling #{setting_name} "

    error "No such setting: #{setting_name}" unless setting

    if setting["kind"] == "user"
      message += "for #{Heroku::Auth.user}"
    else
      error "Must specify an app" unless app
      message += "for #{app}"
    end

    action message do
      api.delete_setting setting_name, app
    end
  end

  # labs:enable SETTING
  #
  # enables an experimental setting
  #
  #Example:
  #
  # $ heroku labs:enable ninja-power
  # Enabling ninja-power setting for me@example.org... done
  #
  def enable
    setting_name = shift_argument
    error "Usage: heroku labs:enable SETTING\nMust specify SETTING to enable." unless setting_name
    validate_arguments!

    setting = api.get_features.body.detect { |f| f["name"] == setting_name }
    message = "Enabling #{setting_name} "

    error "No such setting: #{setting_name}" unless setting

    if setting["kind"] == "user"
      message += "for #{Heroku::Auth.user}"
    else
      error "Must specify an app" unless app
      message += "for #{app}"
    end

    setting_data = action(message) do
      api.post_setting(setting_name, app).body
    end

    display "WARNING: This setting is experimental and may change or be removed without notice."
    display "For more information see: #{setting_data["docs"]}" if setting_data["docs"]
  end

private

  # app is not required for these commands, so rescue if there is none
  def app
    super
  rescue Heroku::Command::CommandFailed
    nil
  end

  def display_settings(settings)
    longest_name = settings.map { |f| f["name"].to_s.length }.sort.last
    settings.each do |setting|
      toggle = setting["enabled"] ? "[+]" : "[ ]"
      display "%s %-#{longest_name}s  %s" % [ toggle, setting["name"], setting["summary"] ]
    end
  end

end
