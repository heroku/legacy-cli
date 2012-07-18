require "heroku/command/base"
require "heroku/updater"

# update the heroku client
#
class Heroku::Command::Update < Heroku::Command::Base

  # update
  #
  # update the heroku client
  #
  # Example:
  #
  # $ heroku update
  # Updating from v1.2.3... done, updated to v2.3.4
  #
  def index
    validate_arguments!
    update_from_url("https://toolbelt.herokuapp.com/download/zip")
  end

  # update:beta
  #
  # update to the latest beta client
  #
  # $ heroku update
  # Updating from v1.2.3... done, updated to v2.3.4.pre
  #
  def beta
    validate_arguments!
    update_from_url("https://toolbelt.herokuapp.com/download/beta-zip")
  end

private

  def update_from_url(url)
    Heroku::Updater.check_disabled!
    action("Updating from #{Heroku::VERSION}") do
      new_version = Heroku::Updater.update(url)
      if new_version == Heroku::VERSION
        status("nothing to update")
      else
        status("updated to #{new_version}")
      end
    end
  end

end
