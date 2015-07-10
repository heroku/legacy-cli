require "heroku/command/base"

module Heroku::Command

  # run heroku app locally
  class Local < Base

    # Usage: heroku local [PROCESSNAME]
    #
    #    -f, --procfile PROCFILE # use a different Procfile
    #    -e, --env ENV       # location of env file (defaults to .env)
    #    -c, --concurrency CONCURRENCY # number of processes to start
    #    -p, --port PORT     # port to listen on
    #    -r, --restart       # restart process if it dies
    #
    #   Start the application specified by a Procfile (defaults to ./Procfile)
    #
    #   Examples:
    #
    #     heroku local
    #     heroku local web
    #     heroku local -f Procfile.test -e .env.test
    #
    def index
      Heroku::JSPlugin.install('heroku-local')
      Heroku::JSPlugin.run('local', nil, ARGV[1..-1])
    end
  end
end
