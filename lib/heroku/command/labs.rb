require "heroku/command/base"

# manage optional features
#
class Heroku::Command::Labs < Heroku::Command::Base

  # labs
  #
  # lists available features for an app
  #
  #Example:
  #
  # $ heroku labs
  # === myapp Available Features
  # user_env_compile: Add user config vars to the environment during slug compilation
  #
  # === myapp Enabled Features
  # sigterm-all: When stopping a dyno, send SIGTERM to all processes rather than only to the root process.
  #
  # === email@example.com Available Features
  # sumo-rankings: Heroku Sumo ranks and visualizes the scale of your app, and suggests the optimum combination of dynos and add-ons to take it to the next level.
  #
  def index
    validate_arguments!

    features_data = api.get_features(app).body

    app_features, user_features = features_data.partition do |feature|
      feature["kind"] == "app"
    end

    if app
      display_features "#{app} Features", app_features
    end

    display_features "#{Heroku::Auth.user} Features", user_features
  end

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
      error("Usage: heroku labs:info FEATURE")
    end
    validate_arguments!

    feature_data = api.get_feature(feature_name, app).body
    styled_header(feature_data['name'])
    styled_hash({
      'Summary' => feature_data['summary'],
      'Docs'    => feature_data['docs']
    })
  end

  # labs:enable FEATURE
  #
  # enables FEATURE on an app
  #
  #Example:
  #
  # $ heroku labs:enable user_env_compile
  # Enabling user_env_compile for myapp... done
  #
  def enable
    unless feature_name = shift_argument
      error("Usage: heroku labs:enable FEATURE")
    end
    validate_arguments!

    message = "Enabling #{feature_name}"
    message += " for #{app}" if app
    action(message) do
      api.post_feature(feature_name, app)
    end
    display("WARNING: This feature is experimental and may change or be removed without notice.")
  end

  # labs:disable FEATURE
  #
  # disables FEATURE on an app
  #
  #Example:
  #
  # $ heroku labs:disable user_env_compile
  # Disabling user_env_compile for myapp... done
  #
  def disable
    unless feature_name = shift_argument
      error("Usage: heroku labs:disable FEATURE")
    end
    validate_arguments!

    message = "Disabling #{feature_name}"
    message += " for #{app}" if app
    action(message) do
      api.delete_feature(feature_name, app)
    end
  end

private

  def app
    # app is not required for these commands, so rescue if there is none
    super
  rescue Heroku::Command::CommandFailed
    nil
  end

  def display_features(header, features)
    unless features.empty?
      styled_header(header)
      feature_data = []
      features.sort_by { |f| f["enabled"].to_s }.reverse.each do |feature|
        toggle = feature["enabled"] ? "[+]" : "[ ]"
        feature_data << [ "#{toggle} #{feature["name"]}", feature["summary"] ]
      end
      styled_array feature_data, :sort => false
    end
  end

end
