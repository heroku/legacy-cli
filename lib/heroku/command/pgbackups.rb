require "heroku/client/pgbackups"
require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"

module Heroku::Command

  # manage backups of heroku postgresql databases
  class Pgbackups < Base

    include Heroku::Helpers::HerokuPostgresql

    # pgbackups
    #
    # list captured backups
    #
    def index
      validate_arguments!

      backups = []
      pgbackup_client.get_transfers.each { |t|
        next unless backup_types.member?(t['to_name']) && !t['error_at'] && !t['destroyed_at']
        backups << {
          'id'          => backup_name(t['to_url']),
          'created_at'  => t['created_at'],
          'status'      => transfer_status(t),
          'size'        => t['size'],
          'database'    => t['from_name']
        }
      }

      if backups.empty?
        no_backups_error!
      else
        display_table(
          backups,
          %w{ id created_at status size database },
          ["ID", "Backup Time", "Status", "Size", "Database"]
        )
      end
    end

    # pgbackups:url [BACKUP_ID]
    #
    # get a temporary URL for a backup
    #
    def url
      name = shift_argument
      validate_arguments!

      if name
        b = pgbackup_client.get_backup(name)
      else
        b = pgbackup_client.get_latest_backup
      end
      unless b['public_url']
        error("No backup found.")
      end
      if $stdout.isatty
        display '"'+b['public_url']+'"'
      else
        display b['public_url']
      end
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
      attachment = hpg_resolve(shift_argument, "DATABASE_URL")
      validate_arguments!

      from_name = attachment.display_name
      from_url  = attachment.url
      to_url    = nil # server will assign
      to_name   = "BACKUP"

      opts      = {:expire => options[:expire]}

      backup = transfer!(from_url, from_name, to_url, to_name, opts)

      to_uri = URI.parse backup["to_url"]
      backup_id = to_uri.path.empty? ? "error" : File.basename(to_uri.path, '.*')
      display "\n#{from_name}  ----backup--->  #{backup_id}"

      backup = poll_transfer!(backup)

      if backup["error_at"]
        message  =   "An error occurred and your backup did not finish."
        message += "\nPlease run `heroku logs --ps pgbackups` for details."
        message += "\nThe database is not yet online. Please try again." if backup['log'] =~ /Name or service not known/
        message += "\nThe database credentials are incorrect."           if backup['log'] =~ /psql: FATAL:/
        error(message)
      end
    end

    # pgbackups:restore [<DATABASE> [BACKUP_ID|BACKUP_URL]]
    #
    # restore a backup to a database
    #
    # if no DATABASE is specified, defaults to DATABASE_URL and latest backup
    # if DATABASE is specified, but no BACKUP_ID, defaults to latest backup
    #
    def restore
      if 0 == args.size
        attachment = hpg_resolve(nil, "DATABASE_URL")
        to_name = attachment.display_name
        to_url  = attachment.url
        backup_id = :latest
      elsif 1 == args.size
        attachment = hpg_resolve(shift_argument)
        to_name = attachment.display_name
        to_url  = attachment.url
        backup_id = :latest
      else
        attachment = hpg_resolve(shift_argument)
        to_name = attachment.display_name
        to_url  = attachment.url
        backup_id = shift_argument
      end

      if :latest == backup_id
        backup = pgbackup_client.get_latest_backup
        no_backups_error! if {} == backup
        to_uri = URI.parse backup["to_url"]
        backup_id = File.basename(to_uri.path, '.*')
        backup_id = "#{backup_id} (most recent)"
        from_url  = backup["to_url"]
        from_name = "BACKUP"
      elsif backup_id =~ /^http(s?):\/\//
        from_url  = backup_id
        from_name = "EXTERNAL_BACKUP"
        from_uri  = URI.parse backup_id
        backup_id = from_uri.path.empty? ? from_uri : File.basename(from_uri.path)
      else
        backup = pgbackup_client.get_backup(backup_id)
        abort("Backup #{backup_id} already destroyed.") if backup["destroyed_at"]

        from_url  = backup["to_url"]
        from_name = "BACKUP"
      end

      message = "#{to_name}  <---restore---  "
      padding = " " * message.length
      display "\n#{message}#{backup_id}"
      if backup
        display padding + "#{backup['from_name']}"
        display padding + "#{backup['created_at']}"
        display padding + "#{backup['size']}"
      end

      if confirm_command
        restore = transfer!(from_url, from_name, to_url, to_name)
        restore = poll_transfer!(restore)

        if restore["error_at"]
          message  =   "An error occurred and your restore did not finish."
          if restore['log'] =~ /Invalid dump format: .*: XML  document text/
            message += "\nThe backup url is invalid. Use `pgbackups:url` to generate a new temporary URL."
          else
            message += "\nPlease run `heroku logs --ps pgbackups` for details."
          end
          error(message)
        end
      end
    end

    # pgbackups:destroy BACKUP_ID
    #
    # destroys a backup
    #
    def destroy
      unless name = shift_argument
        error("Usage: heroku pgbackups:destroy BACKUP_ID\nMust specify BACKUP_ID to destroy.")
      end
      backup = pgbackup_client.get_backup(name)
      if backup["destroyed_at"]
        error("Backup #{name} already destroyed.")
      end

      action("Destroying #{name}") do
        pgbackup_client.delete_backup(name)
      end
    end

    protected

    def transfer_status(t)
      if t['finished_at']
        "Finished @ #{t["finished_at"]}"
      elsif t['started_at']
        step = t['progress'] && t['progress'].split[0]
        step.nil? ? 'Unknown' : step_map[step]
      else
        "Unknown"
      end
    end

    def config_vars
      @config_vars ||= api.get_config_vars(app).body
    end

    def pgbackup_client
      pgbackups_url = ENV["PGBACKUPS_URL"] || config_vars["PGBACKUPS_URL"]
      error("Please add the pgbackups addon first via:\nheroku addons:add pgbackups") unless pgbackups_url
      @pgbackup_client ||= Heroku::Client::Pgbackups.new(pgbackups_url)
    end

    def backup_name(to_url)
      # translate s3://bucket/email/foo/bar.dump => foo/bar
      parts = to_url.split('/')
      parts.slice(4..-1).join('/').gsub(/\.dump$/, '')
    end

    def transfer!(from_url, from_name, to_url, to_name, opts={})
      pgbackup_client.create_transfer(from_url, from_name, to_url, to_name, opts)
    end

    def poll_error(app)
      error <<-EOM
Failed to query the PGBackups status API. Your backup may still be running.
Verify the status of your backup with `heroku pgbackups -a #{app}`
You can also watch progress with `heroku logs --tail --ps pgbackups -a #{app}`
      EOM
    end

    def poll_transfer!(transfer)
      display "\n"

      if transfer["errors"]
        transfer["errors"].values.flatten.each { |e|
          output_with_bang "#{e}"
        }
        abort
      end

      while true
        update_display(transfer)
        break if transfer["finished_at"]

        sleep_time = 1
        begin
          sleep(sleep_time)
          transfer = pgbackup_client.get_transfer(transfer["id"])
        rescue
          if sleep_time > 300
            poll_error(app)
          else
            sleep_time *= 2
            retry
          end
        end
      end

      display "\n"

      return transfer
    end

    def step_map
      @step_map ||= {
        "dump"      => "Capturing",
        "upload"    => "Storing",
        "download"  => "Retrieving",
        "restore"   => "Restoring",
        "gunzip"    => "Uncompressing",
        "load"      => "Restoring",
      }
    end

    def update_display(transfer)
      @ticks            ||= 0
      @last_updated_at  ||= 0
      @last_logs        ||= []
      @last_progress    ||= ["", 0]

      @ticks += 1

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

    private

    def no_backups_error!
      error("No backups. Capture one with `heroku pgbackups:capture`.")
    end

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
