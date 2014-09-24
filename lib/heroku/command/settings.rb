require "heroku/command/base"

# manage optional settings
#
class Heroku::Command::Settings < Heroku::Command::Base

  # settings
  #
  # list available settings
  #
  #Example:
  #
  # === App Settings (glacial-retreat-5913)
  # [ ] preboot            Provide seamless web dyno deploys
  #
  def index
    validate_arguments!

    app_settings = api.get_features(app).body.select do |feature|
      feature["state"] == "general"
    end

    app_settings.sort_by! do |feature|
      feature["name"]
    end

    display_app = app || "no app specified"

    styled_header "App Settings (#{display_app})"
    display_settings app_settings
  end

  alias_command "settings:list", "settings"

  # settings:info SETTING
  #
  # displays additional information about SETTING
  #
  #Example:
  #
  # $ heroku settings:info preboot
  # === preboot
  # Docs:    https://devcenter.heroku.com/articles/preboot
  # Summary: Provide seamless web dyno deploys
  #
  def info
    unless setting_name = shift_argument
      error("Usage: heroku settings:info SETTING\nMust specify SETTING for info.")
    end
    validate_arguments!

    setting_data = api.get_feature(setting_name, app).body
    styled_header(setting_data['name'])
    styled_hash({
      'Summary' => setting_data['summary'],
      'Docs'    => setting_data['docs']
    })
  end

  # settings:disable SETTING
  #
  # disables a setting
  #
  #Example:
  #
  # $ heroku settings:disable preboot
  # Disabling preboot setting for me@example.org... done
  #
  def disable
    setting_name = shift_argument
    error "Usage: heroku settings:disable SETTING\nMust specify SETTING to disable." unless setting_name
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
      api.delete_feature setting_name, app
    end
  end

  # settings:enable SETTING
  #
  # enables an setting
  #
  #Example:
  #
  # $ heroku settings:enable preboot
  # Enabling preboot setting for me@example.org... done
  #
  def enable
    setting_name = shift_argument
    error "Usage: heroku settings:enable SETTING\nMust specify SETTING to enable." unless setting_name
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
      api.post_feature(setting_name, app).body
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
