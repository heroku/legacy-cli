require "heroku/command/base"

module Heroku::Command

  # manage backups of heroku postgresql databases
  # removed: see heroku pg:backups

  class Pgbackups < Base
    # pgbackups
    #
    # list captured backups
    #
    def index
    error("'heroku pgbackups' has been removed.
Please see 'heroku pg:backups' instead.
More Information: https://devcenter.heroku.com/articles/heroku-postgres-backups")
    end

    # pgbackups:url [BACKUP_ID]
    #
    # get a temporary URL for a backup
    #
    def url
    error("'heroku pgbackups url' has been removed.
Please see 'heroku pg:backups public-url' instead.
More Information: https://devcenter.heroku.com/articles/heroku-postgres-backups")
    end

    # pgbackups:capture [DATABASE]
    #
    # capture a backup from a database id
    #
    # if no DATABASE is specified, defaults to DATABASE_URL
    #
    # -e, --expire  # if no slots are available, destroy the oldest manual backup to make room
    #
    def capture
    error("'heroku pgbackups capture' has been removed.
Please see 'heroku pg:backups capture' instead. The '-e/--expire' flag is no longer supported.
More Information: https://devcenter.heroku.com/articles/heroku-postgres-backups")
    end

    # pgbackups:restore [<DATABASE> [BACKUP_ID|BACKUP_URL]]
    #
    # restore a backup to a database
    #
    # if no DATABASE is specified, defaults to DATABASE_URL and latest backup
    # if DATABASE is specified, but no BACKUP_ID, defaults to latest backup
    #
    def restore
    error("'heroku pgbackups restore' has been removed.
Please see 'heroku pg:backups restore' instead.
More Information: https://devcenter.heroku.com/articles/heroku-postgres-backups")
    end

    # pgbackups:destroy BACKUP_ID
    #
    # destroys a backup
    #
    def destroy
    error("'heroku pgbackups destroy' has been removed.
Please see 'heroku pg:backups delete' instead.
More Information: https://devcenter.heroku.com/articles/heroku-postgres-backups")
    end

    # pgbackups:transfer [SOURCE DATABASE] DESTINATION DATABASE
    #
    # direct database-to-database transfer
    #
    # If no DATABASE is specified, defaults to DATABASE_URL.
    # The pgbackups add-on is required to use direct transfers
    #
    #Example:
    #
    #$ heroku pgbackups:transfer green teal --app example
    #
    # note that both the FROM and TO database must be accessible to the pgbackups service
    #$ heroku pgbackups:transfer DATABASE postgres://user:password@host/dbname --app example
    #
    def transfer
    error("'heroku pgbackups:transfer' has been removed.
Please see 'heroku pg:copy' instead.
More Information: https://devcenter.heroku.com/articles/heroku-postgres-backups")
    end
  end
end
