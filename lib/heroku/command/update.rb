require "heroku/command/base"
require "heroku/updater"

module Heroku::Command

  # update the heroku client
  class Update < Base

    # update
    #
    # update the heroku client
    #
    def index
      if message = Heroku::Updater.disable
        error message
      end

      action("Updating to latest client") do
        Heroku::Updater.update
      end
    end

    # update:beta
    #
    # update to the latest beta client
    #
    def beta
      action("Updating to latest beta client") do
        Heroku::Updater.update(true)
      end
    end
  end
end
