require "heroku/command/base"

# manage optional features
#
class Heroku::Command::Labs < Heroku::Command::Base

  # labs
  #
  # list experimental features
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

    user_features, app_features = api.get_features(app).body.sort_by do |feature|
      feature["name"]
    end.partition do |feature|
      feature["kind"] == "user"
    end

    display_app = app || "no app specified"

    styled_header "User Features (#{Heroku::Auth.user})"
    display_features user_features
    display
    styled_header "App Features (#{display_app})"
    display_features app_features
  end

  alias_command "labs:list", "labs"

  # labs:info FEATURE
  #
  # displays additional information about FEATURE
  #
  #Example:
  #
  # $ heroku labs:info user_env_compile
  # === user_env_compile
  # Docs:    http://devcenter.heroku.com/articles/labs-user-env-compile
  # Summary: Add user config vars to the environment during slug compilation
  #
  def info
    unless feature_name = shift_argument
      error("Usage: heroku labs:info FEATURE\nMust specify FEATURE for info.")
    end
    validate_arguments!

    feature_data = api.get_feature(feature_name, app).body
    styled_header(feature_data['name'])
    styled_hash({
      'Summary' => feature_data['summary'],
      'Docs'    => feature_data['docs']
    })
  end

  # labs:disable FEATURE
  #
  # disables an experimental feature
  #
  #Example:
  #
  # $ heroku labs:disable ninja-power
  # Disabling ninja-power feature for me@example.org... done
  #
  def disable
    feature_name = shift_argument
    error "Usage: heroku labs:disable FEATURE\nMust specify FEATURE to disable." unless feature_name
    validate_arguments!

    feature = api.get_features(app).body.detect { |f| f["name"] == feature_name }
    message = "Disabling #{feature_name} "

    error "No such feature: #{feature_name}" unless feature

    if feature["kind"] == "user"
      message += "for #{Heroku::Auth.user}"
    else
      error "Must specify an app" unless app
      message += "for #{app}"
    end

    action message do
      api.delete_feature feature_name, app
    end
  end

  # labs:enable FEATURE
  #
  # enables an experimental feature
  #
  #Example:
  #
  # $ heroku labs:enable ninja-power
  # Enabling ninja-power feature for me@example.org... done
  #
  def enable
    feature_name = shift_argument
    error "Usage: heroku labs:enable FEATURE\nMust specify FEATURE to enable." unless feature_name
    validate_arguments!

    feature = api.get_features.body.detect { |f| f["name"] == feature_name }
    message = "Enabling #{feature_name} "

    error "No such feature: #{feature_name}" unless feature

    if feature["kind"] == "user"
      message += "for #{Heroku::Auth.user}"
    else
      error "Must specify an app" unless app
      message += "for #{app}"
    end

    feature_data = action(message) do
      api.post_feature(feature_name, app).body
    end

    display "WARNING: This feature is experimental and may change or be removed without notice."
    display "For more information see: #{feature_data["docs"]}" if feature_data["docs"]
  end

private

  # app is not required for these commands, so rescue if there is none
  def app
    super
  rescue Heroku::Command::CommandFailed
    nil
  end

  def display_features(features)
    longest_name = features.map { |f| f["name"].to_s.length }.sort.last
    features.each do |feature|
      toggle = feature["enabled"] ? "[+]" : "[ ]"
      display "%s %-#{longest_name}s  %s" % [ toggle, feature["name"], feature["summary"] ]
    end
  end

end
