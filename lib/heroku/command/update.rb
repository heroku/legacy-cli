require "heroku/command/base"

module Heroku::Command

  # update the heroku client
  class Update < Base

    # update
    #
    # update the heroku client
    #
    def index
      output_with_arrow("Updating to latest client... ", false)
      Heroku::Updater.update
      display "done"
    rescue Exception => ex
      display "failed"
      display "   !   #{ex.message}"
    end

    # update:beta
    #
    # update to the latest beta client
    #
    def beta
      output_with_arrow("Updating to latest beta client... ", false)
      Heroku::Updater.update(true)
      display "done"
    rescue Exception => ex
      display "failed"
      display "   !   #{ex.message}"
    end
  end
end
