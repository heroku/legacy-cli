require "heroku/command/base"

# manage optional features
#
class Heroku::Command::Labs < Heroku::Command::Base

  # labs
  #
  # lists available features for an app
  #
  def index
    features = heroku.list_features(app)
    longest = features.map { |f| f["name"].length }.sort.last
    app_features, user_features = features.partition { |f| f["kind"] == "app" }

    if app
      display "=== App Features (%s)" % app
      display_features app_features, longest
      display
    end

    display "=== User Features (%s)" % Heroku::Auth.user
    display_features user_features, longest
  end

  # labs:info FEATURE
  #
  # displays additional information about FEATURE
  #
  def info
    if feature_name = args.shift
      feature_name = feature_name.downcase.strip
    else
      error("Usage: heroku labs:info FEATURE")
    end
    feature = heroku.get_feature(app, feature_name)
    display "=== #{feature['name']}"
    display "Summary: %s" % feature["summary"]
    display "Docs:    %s" % feature["docs"]
  end

  # labs:enable FEATURE
  #
  # enables FEATURE on an app
  #
  def enable
    if feature_name = args.shift
      feature_name = feature_name.downcase.strip
    else
      error("Usage: heroku labs:enable FEATURE")
    end
    message = "Enabling #{feature_name}"
    message += " for #{app}" if app
    action(message) do
      heroku.enable_feature(app, feature_name)
    end
    display "WARNING: This feature is experimental and may change or be removed without notice."
  end

  # labs:disable FEATURE
  #
  # disables FEATURE on an app
  #
  def disable
    if feature_name = args.shift
      feature_name = feature_name.downcase.strip
    else
      error("Usage: heroku labs:disable FEATURE")
    end
    message = "Disabling #{feature_name}"
    message += " for #{app}" if app
    action(message) do
      heroku.disable_feature(app, feature_name)
    end
  end

private

  def app
    super
  rescue Heroku::Command::CommandFailed
    nil
  end

  def display_features(features, longest)
    features.each do |feature|
      display "[%s] %-#{longest}s  # %s" % [
        feature["enabled"] ? "+" : " ",
        feature["name"],
        feature["summary"]
      ]
    end
  end

end
