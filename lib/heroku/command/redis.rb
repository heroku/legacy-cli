require "heroku/command/base"

module Heroku::Command

  # list redis databases for an app
  #
  class Redis < Base

    # redis [DATABASE]
    #
    # Get information about redis database
    #
    #
    def index
      Heroku::JSPlugin.install('heroku-redis')
      Heroku::JSPlugin.run('redis:info', nil, ARGV[1..-1])
    end
  end
end
