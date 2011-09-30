require "heroku/command/base"

module Heroku::Command

  # display syslog drains for an app
  #
  class Drains < BaseWithApp

    # drains
    #
    # manage syslog drains
    #
    # drains add URL     # add a syslog drain
    # drains remove URL  # remove a syslog drain
    #
    def drains
      if args.empty?
        puts heroku.list_drains(app)
        return
      end

      case args.shift
        when "add"
          url = args.shift
          puts heroku.add_drain(app, url)
          return
        when "remove"
          url = args.shift
          puts heroku.remove_drain(app, url)
          return
      end
      raise(CommandFailed, "usage: heroku drains <add | remove>")
    end

  end
end

