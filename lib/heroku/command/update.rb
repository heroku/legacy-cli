require "heroku/command/base"

module Heroku::Command

  # update the heroku client
  class Stack < BaseWithApp

    # update
    #
    # update the heroku client
    #
    def index
      Heroku::Updater.update
    end
  end
end
