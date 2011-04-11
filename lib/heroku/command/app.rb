require "heroku/command/base"

require 'readline'
require 'launchy'

module Heroku::Command
  class App < Base

    # version
    #
    # show heroku client version
    #
    def version
      display Heroku::Client.gem_version_string
    end

  end
end
