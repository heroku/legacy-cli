require "heroku/command/base"

module Heroku::Command

  # clone an existing app
  #
  class Fork < Base

    # fork
    #
    # --from FROM         # app to fork from
    # --to TO             # app to create
    # -s, --stack STACK   # specify a stack for the new app
    # --region REGION     # specify a region
    # --skip-pg           # skip postgres databases
    #
    # Copy config vars and Heroku Postgres data, and re-provision add-ons to a new app.
    # New app name should not be an existing app. The new app will be created as part of the forking process.
    #
    #Example:
    #
    # $ heroku fork --from my-production-app --to my-development-app
    # Forking my-production-app... done. Forked to my-development-app
    # Deploying 60a8b0f to my-development-app... done
    # Adding addon memcachier:dev to my-development-app... done
    # Adding addon heroku-postgresql:hobby-dev to my-development-app... done
    # Transferring HEROKU_POSTGRESQL_AMBER to DATABASE...
    # Progress: done
    # Copying config vars:
    #   LANG
    #   RAILS_ENV
    #   RACK_ENV
    #   SECRET_KEY_BASE
    #   RAILS_SERVE_STATIC_FILES
    #   ... done
    # Fork complete. View it at https://my-development-app.herokuapp.com/
    def index
      Heroku::JSPlugin.install('heroku-fork')
      Heroku::JSPlugin.run('fork', nil, ARGV[1..-1])
    end
  end
end
