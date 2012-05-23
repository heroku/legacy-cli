require "heroku/command/base"

# manage optional features
#
class Heroku::Command::Labs < Heroku::Command::Base

  # labs
  #
  # lists available features for an app
  #
  def index
    validate_arguments!

    features_data = api.get_features(app).body
    app_features, user_features = features_data.partition do |feature|
      feature["kind"] == "app"
    end

#  def display_features(features, longest)
#    features.each do |feature|
#      display "[%s] %-#{longest}s  # %s" % [
#        feature["enabled"] ? "+" : " ",
#        feature["name"],
#        feature["summary"]
#      ]
#    end
#  end

    if app
      enabled_app_features, available_app_features = app_features.partition do |feature|
        feature['enabled'] == true
      end
      display_features("#{app} Available Features", available_app_features)
      display_features("#{app} Enabled Features", enabled_app_features)
    end

    enabled_user_features, available_user_features = user_features.partition do |feature|
      feature['enabled'] == true
    end
    display_features("#{Heroku::Auth.user} Available Features", available_user_features)
    display_features("#{Heroku::Auth.user} Enabled Features", enabled_user_features)
  end

  # labs:info FEATURE
  #
  # displays additional information about FEATURE
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
      feature_data = {}
      features.each do |feature|
        feature_data[feature['name']] = feature['summary']
      end
      styled_hash(feature_data)
      display
    end
  end

end
