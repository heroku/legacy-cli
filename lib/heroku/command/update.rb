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

    if message = Heroku::Updater.disable
      error message
    end

    action("Updating from #{Heroku::VERSION}") do
      Heroku::Updater.update
      /VERSION = "([^"]+)"/ =~ File.read(File.join(Heroku::Updater.updated_client_path, "lib/heroku/version.rb"))
      status("updated to #{$1}")
    end
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

    action("Updating from #{Heroku::VERSION}") do
      Heroku::Updater.update(true)
      /VERSION = "([^"]+)"/ =~ File.read(File.join(Heroku::Updater.updated_client_path, "lib/heroku/version.rb"))
      status("updated to #{$1}")
    end
  end

end
