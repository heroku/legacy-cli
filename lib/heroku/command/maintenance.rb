require "heroku/command/base"

# toggle maintenance mode
#
class Heroku::Command::Maintenance < Heroku::Command::Base

  # maintenance:on
  #
  # put the app into maintenance mode
  #
  #Example:
  #
  # $ heroku maintenance:on
  # Enabling maintenance mode for myapp
  #
  def on
    validate_arguments!

    action("Enabling maintenance mode for #{app}") do
      api.post_app_maintenance(app, :on)
    end

    #heroku.maintenance(app, :on)
    #display "Maintenance mode enabled."
  end

  # maintenance:off
  #
  # take the app out of maintenance mode
  #
  #Example:
  #
  # $ heroku maintenance:off
  # Disabling maintenance mode for myapp
  #
  def off
    validate_arguments!

    action("Disabling maintenance mode for #{app}") do
      api.post_app_maintenance(app, :off)
    end

    #heroku.maintenance(app, :off)
    #display "Maintenance mode disabled."
  end

end
