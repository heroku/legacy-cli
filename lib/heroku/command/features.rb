require "heroku/command/base"

# manage optional features
#
class Heroku::Command::Features < Heroku::Command::Base

  # features
  #
  # list available features
  #
  #Example:
  #
  # === App Features (glacial-retreat-5913)
  # [ ] preboot            Provide seamless web dyno deploys
  #
  def index
    validate_arguments!

    app_features = api.get_features(app).body.select do |feature|
      feature["kind"] == "app" && feature["state"] == "general"
    end

    app_features.sort_by! do |feature|
      feature["name"]
    end

    display_app = app || "no app specified"

    styled_header "App Features (#{display_app})"
    display_features app_features
  end

  alias_command "features:list", "features"

  # features:info FEATURE
  #
  # displays additional information about FEATURE
  #
  #Example:
  #
  # $ heroku features:info preboot
  # === preboot
  # Docs:    https://devcenter.heroku.com/articles/preboot
  # Summary: Provide seamless web dyno deploys
  #
  def info
    unless feature_name = shift_argument
      error("Usage: heroku features:info FEATURE\nMust specify FEATURE for info.")
    end
    validate_arguments!

    feature_data = api.get_feature(feature_name, app).body
    styled_header(feature_data['name'])
    styled_hash({
      'Summary' => feature_data['summary'],
      'Docs'    => feature_data['docs']
    })
  end

  # features:disable FEATURE
  #
  # disables a feature
  #
  #Example:
  #
  # $ heroku features:disable preboot
  # Disabling preboot feature for me@example.org... done
  #
  def disable
    feature_name = shift_argument
    error "Usage: heroku features:disable FEATURE\nMust specify FEATURE to disable." unless feature_name
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

  # features:enable FEATURE
  #
  # enables an feature
  #
  #Example:
  #
  # $ heroku features:enable preboot
  # Enabling preboot feature for me@example.org... done
  #
  def enable
    feature_name = shift_argument
    error "Usage: heroku features:enable FEATURE\nMust specify FEATURE to enable." unless feature_name
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
