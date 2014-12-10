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
  # Updating... done, v1.2.3 updated to v2.3.4
  #
  def index
    validate_arguments!
    update_from_url(false)
  end

  # update:beta
  #
  # update to the latest beta client
  #
  # $ heroku update
  # Updating... done, v1.2.3 updated to v2.3.4.pre
  #
  def beta
    validate_arguments!
    update_from_url(true)
  end

  private

  def update_from_url(prerelease)
    Heroku::Updater.check_disabled!
    Heroku::Updater.update(prerelease)
  end
end
