require "heroku/command/base"

module Heroku::Command

  # display drains for an app
  #
  class Drains < Base

    # drains
    #
    # list all drains
    #
    def index
      puts heroku.list_drains(app)
      return
    end

    # drains:add URL
    #
    # add a drain
    #
    def add
      if url = args.shift
        puts heroku.add_drain(app, url)
        return
      else
        error("Usage: heroku drains:add URL")
      end
    end

    # drains:remove URL
    #
    # remove a drain
    #
    def remove
      if url = args.shift
        puts heroku.remove_drain(app, url)
        return
      else
        error("Usage: heroku drains remove URL")
      end
    end

  end
end
