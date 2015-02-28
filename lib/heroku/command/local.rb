require "heroku/command/base"

module Heroku::Command

  # run heroku app locally
  class Local < Base

    # local:start [PROCESSNAME]
    #
    # run heroku app locally
    #
    # Start the application specified by a Procfile (defaults to ./Procfile)
    #
    # Examples:
    #
    #   heroku local:start
    #   heroku local:start web
    #   heroku local:start -f Procfile.test -e .env.test
    #
    # -f, --procfile PROCFILE
    # -e, --env ENV
    # -c, --concurrency CONCURRENCY
    # -p, --port PORT
    # -r, --r
    #
    def start
      Heroku::JSPlugin.setup
      Heroku::JSPlugin.install('heroku-local') unless Heroku::JSPlugin.is_plugin_installed?('heroku-local')
      Heroku::JSPlugin.run('local', 'start', ARGV[1..-1])
    end
  end
end
