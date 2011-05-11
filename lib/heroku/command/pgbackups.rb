require "heroku/command/base"
require "heroku/pgutils"
require "pgbackups/client"

module Heroku::Command

  # manage backups of heroku postgresql databases
  class Pgbackups < BaseWithApp
    include PgUtils

    # pgbackups
    #
    # list captured backups
    #
    def index
      backups = []
      pgbackup_client.get_transfers.each { |t|
        next unless backup_types.member?(t['to_name']) && !t['error_at'] && !t['destroyed_at']
        backups << [backup_name(t['to_url']), t['created_at'], t['size'], t['from_name'], ]
      }

      if backups.empty?
        display("No backups. Capture one with `heroku pgbackups:capture`.")
      else
        display Display.new.render([["ID", "Backup Time", "Size", "Database"]], backups)
      end
    end

    # pgbackups:url [BACKUP_ID]
    #
    # get a temporary URL for a backup
    #
    def url
      if name = args.shift
        b = pgbackup_client.get_backup(name)
      else
        b = pgbackup_client.get_latest_backup
      end
      abort("No backup found.") unless b['public_url']
      display b['public_url']
    end

    # pgbackups:capture [DATABASE]
    #
    # capture a backup from a database id
    #
    # if no DATABASE is specified, defaults to DATABASE_URL
    #
    # -e, --expire  # if no slots are available to capture, delete the oldest backup to make room
    #
    def capture
      expire = extract_option("--expire")
      db_id = args.shift
      from_name, from_url = resolve_db_id(db_id, :default => "DATABASE_URL")
      db_id ||= "DATABASE_URL"

      abort(" !   No database addon detected.") unless from_url

      to_name = "BACKUP"
      to_url = nil # server will assign

      opts = {}
      opts[:expire] = true if expire
      backup = transfer!(from_url, from_name, to_url, to_name, opts)
      to_uri = URI.parse backup["to_url"]
      backup_id = to_uri.path.empty? ? "error" : File.basename(to_uri.path, '.*')
      display "\n#{db_id}  ----backup--->  #{backup_id}"

      backup = poll_transfer!(backup)

      if backup["error_at"]
        message  =   " !    An error occurred and your backup did not finish."
        message += "\n !    The database is not yet online. Please try again." if backup['log'] =~ /Name or service not known/
        message += "\n !    The database credentials are incorrect."           if backup['log'] =~ /psql: FATAL:/
        abort(message)
      end
    end

    # pgbackups:restore [BACKUP_ID]
    #
    # restore a backup to a database id
    #
    # if no BACKUP_ID is specified, uses the most recent backup
    #
    # -d, --db DATABASE  # the database id to target for the restore
    #
    def restore
      db_id = extract_option("--db")
      confirm = extract_option("--confirm")
      to_name, to_url = resolve_db_id(db_id, :default => "DATABASE_URL")
      db_id = to_name

      abort(" !   No database addon detected.") unless to_url

      backup_id = args.shift

      if backup_id =~ /^http(s?):\/\//
        from_url  = backup_id
        from_name = "EXTERNAL_BACKUP"
        from_uri  = URI.parse backup_id
        backup_id = from_uri.path.empty? ? from_uri : File.basename(from_uri.path)
      else
        if backup_id
          backup = pgbackup_client.get_backup(backup_id)
          abort("Backup #{backup_id} already deleted.") if backup["destroyed_at"]
        else
          backup = pgbackup_client.get_latest_backup
          to_uri = URI.parse backup["to_url"]
          backup_id = File.basename(to_uri.path, '.*')
          backup_id = "#{backup_id} (most recent)"
        end

        from_url  = backup["to_url"]
        from_name = "BACKUP"
      end

      db_display = db_id
      db_display += " (DATABASE_URL)" if db_id != "DATABASE_URL" && config_vars[db_id] == config_vars["DATABASE_URL"]
      padding = " " * "#{db_display}  <---restore---  ".length
      display "\n#{db_display}  <---restore---  #{backup_id}"
      if backup
        display padding + "#{backup['from_name']}"
        display padding + "#{backup['created_at']}"
        display padding + "#{backup['size']}"
      end

      @args += ['--confirm', confirm]
      if confirm_command
        restore = transfer!(from_url, from_name, to_url, to_name)
        restore = poll_transfer!(restore)

        if restore["error_at"]
          message  =   " !    An error occurred and your restore did not finish."
          message += "\n !    The backup url is invalid. Use `pgbackups:url` to generate a new temporary URL." if restore['log'] =~ /Invalid dump format: .*: XML  document text/
          abort(message)
        end
      end
    end

    # pgbackups:destroy BACKUP_ID
    #
    # destroys a backup
    #
    def destroy
      name = args.shift
      abort("Backup name required") unless name
      backup = pgbackup_client.get_backup(name)
      abort("Backup #{name} already deleted.") if backup["destroyed_at"]

      result = pgbackup_client.delete_backup(name)
      if result
        display("Backup #{name} deleted.")
      else
        abort("Error deleting backup #{name}.")
      end
    end

    protected

    def config_vars
      @config_vars ||= heroku.config_vars(app)
    end

    def pgbackup_client
      pgbackups_url = ENV["PGBACKUPS_URL"] || config_vars["PGBACKUPS_URL"]
      abort(" !   Please add the pgbackups addon first via:\nheroku addons:add pgbackups") unless pgbackups_url
      @pgbackup_client ||= PGBackups::Client.new(pgbackups_url)
    end

    def backup_name(to_url)
      # translate s3://bucket/email/foo/bar.dump => foo/bar
      parts = to_url.split('/')
      parts.slice(4..-1).join('/').gsub(/\.dump$/, '')
    end

    def transfer!(from_url, from_name, to_url, to_name, opts={})
      pgbackup_client.create_transfer(from_url, from_name, to_url, to_name, opts)
    end

    def poll_transfer!(transfer)
      display "\n"

      if transfer["errors"]
        transfer["errors"].values.flatten.each { |e|
          display " !    #{e}"
        }
        abort
      end

      while true
        update_display(transfer)
        break if transfer["finished_at"]

        sleep 1
        transfer = pgbackup_client.get_transfer(transfer["id"])
      end

      display "\n"

      return transfer
    end

    def update_display(transfer)
      @ticks            ||= 0
      @last_updated_at  ||= 0
      @last_logs        ||= []
      @last_progress    ||= ["", 0]

      @ticks += 1

      step_map = {
        "dump"      => "Capturing",
        "upload"    => "Storing",
        "download"  => "Retrieving",
        "restore"   => "Restoring",
        "gunzip"    => "Uncompressing",
        "load"      => "Restoring",
      }

      if !transfer["log"]
        @last_progress = ['pending', nil]
        redisplay "Pending... #{spinner(@ticks)}"
      else
        logs        = transfer["log"].split("\n")
        new_logs    = logs - @last_logs
        @last_logs  = logs

        new_logs.each do |line|
          matches = line.scan /^([a-z_]+)_progress:\s+([^ ]+)/
          next if matches.empty?

          step, amount = matches[0]

          if ['done', 'error'].include? amount
            # step is done, explicitly print result and newline
            redisplay "#{@last_progress[0].capitalize}... #{amount}\n"
          end

          # store progress, last one in the logs will get displayed
          step = step_map[step] || step
          @last_progress = [step, amount]
        end

        step, amount = @last_progress
        unless ['done', 'error'].include? amount
          redisplay "#{step.capitalize}... #{amount} #{spinner(@ticks)}"
        end
      end
    end

    class Display
      attr_reader :columns, :rows

      def initialize(columns=nil, rows=nil, opts={})
        @columns = columns
        @rows = rows
        @opts = opts.update(:display_columns => @columns, :display_rows => @rows)
      end

      def render(*data)
        _data = data
        data = DataSource.new(data, @opts)

        # join in grid lines
        lines = []
        data.rows.each { |row|
          lines << row.join(@opts[:delimiter] || " | ")
        }

        # insert header grid line
        if _data.length > 1
          grid_row = data.rows.first.map { |datum| "-" * datum.length }
          grid_line = grid_row.join("-+-")
          lines.insert(1, grid_line)
          lines << "" # trailing newline
        end
        return lines.join("\n")
      end

      class DataSource
        attr_reader :rows, :columns

        def initialize(data, opts={})
          rows = []
          data.each { |d| rows += d }
          columns = rows.transpose

          max_widths = columns.map { |c|
            c.map { |datum| datum.length }.max
          }

          max_widths = [10, 10] if opts[:display_columns]

          @columns = []
          columns.each_with_index { |c,i|
            column = @columns[i] = []
            c.each { |d| column << d.ljust(max_widths[i]) }
          }
          @rows = @columns.transpose
        end
      end
    end

    private

    # lists all types of backups ('to_name' attribute)
    #
    # Useful when one doesn't care if a backup is of a particular
    # kind, but wants to know what backups of any kind exist.
    #
    def backup_types
      %w[BACKUP DAILY_SCHEDULED_BACKUP HOURLY_SCHEDULED_BACKUP AUTO_SCHEDULED_BACKUP]
    end
  end
end
