require "heroku/command/base"

# manage optional features
#
class Heroku::Command::Labs < Heroku::Command::Base

  # labs [APP]
  #
  # lists enabled features for an app
  #
  #Example:
  #
  # $ heroku labs -a myapp
  # === myapp Enabled Features
  # sigterm-all: When stopping a dyno, send SIGTERM to all processes rather than only to the root process.
  #
  # === email@example.com Enabled Features
  # sumo-rankings: Heroku Sumo ranks and visualizes the scale of your app, and suggests the optimum combination of dynos and add-ons to take it to the next level.
  #
  def index
    validate_arguments!

    if app
      display_features(
        "#{app} Enabled Features",
        { 'enabled' => true, 'kind' => 'app' }
      )
    end

    display_features(
      "#{Heroku::Auth.user} Enabled Features",
      { 'enabled' => true, 'kind' => 'user' }
    )
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
  # disables FEATURE on an app
  #
  #Example:
  #
  # $ heroku labs:disable user_env_compile
  # Disabling user_env_compile for myapp... done
  #
  def disable
    unless feature_name = shift_argument
      error("Usage: heroku labs:disable FEATURE\nMust specify FEATURE to disable.")
    end
    validate_arguments!

    message = "Disabling #{feature_name}"
    message += " for #{app}" if app
    action(message) do
      api.delete_feature(feature_name, app)
    end
  end

  # labs:enable FEATURE
  #
  # enables FEATURE on an app
  #
  #Example:
  #
  # $ heroku labs:enable user_env_compile
  # Enabling user_env_compile for myapp... done
  # For more information see: http://devcenter.heroku.com/articles/labs-user-env-compile
  #
  def enable
    unless feature_name = shift_argument
      error("Usage: heroku labs:enable FEATURE\nMust specify FEATURE to enable.")
    end
    validate_arguments!

    message = "Enabling #{feature_name}"
    message += " for #{app}" if app
    feature_data = nil
    action(message) do
      feature_data = api.post_feature(feature_name, app).body
    end
    display("WARNING: This feature is experimental and may change or be removed without notice.")
    display("For more information see: #{feature_data['docs']}")
  end

  # labs
  #
  # lists available features
  #
  #Example:
  #
  # $ heroku labs:list
  # === App Available Features
  # dot-profile:      Source .profile during dyno startup
  # preboot:          Provide seamless deploys by booting web dynos with new code before killing existing web dynos.
  # user_env_compile: Add user config vars to the environment during slug compilation
  #
  # === User Available Features
  # default-heroku-postgresql-dev: Use the new heroku-postgresql:dev add-on as the default database for Cedar apps.
  #
  def list
    validate_arguments!

    display_features('App Available Features', { 'kind' => 'app' })
    display_features('User Available Features', { 'kind' => 'user' })
  end

private

  def app
    # app is not required for these commands, so rescue if there is none
    super
  rescue Heroku::Command::CommandFailed
    nil
  end

  def display_features(header, attributes)
    @features ||= api.get_features(app).body

    selected_features = @features.dup
    attributes.each do |key, value|
      selected_features = selected_features.select {|feature| feature[key] == value}
    end

    feature_hash = {}
    selected_features.each do |feature|
      feature_hash[feature['name']] = feature['summary']
    end

    if feature_hash.empty?
      display("#{header.split(' ').first} has no enabled features.")
    else
      styled_header(header)
      styled_hash(feature_hash)
      display
    end
  end

end
