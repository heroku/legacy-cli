require "heroku/client/heroku_postgresql"
require "heroku/client/heroku_postgresql_backups"
require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"

class Heroku::Command::Pg < Heroku::Command::Base
  # pg:copy SOURCE TARGET
  #
  # Copy all data from source database to target. At least one of
  # these must be a Heroku Postgres database.
  def copy
    source_db = shift_argument
    target_db = shift_argument

    validate_arguments!

    source = resolve_db_or_url(source_db)
    target = resolve_db_or_url(target_db)

    if source.url == target.url
      abort("Cannot copy database to itself")
    end

    attachment = target.attachment || source.attachment

    message = "WARNING: Destructive Action"
    message << "\nThis command will remove all data from #{target.name}"
    message << "\nData from #{source.name} will then be transferred to #{target.name}"
    message << "\nThis command will affect the app: #{app}"

    if confirm_command(app, message)
      xfer = hpg_client(attachment).pg_copy(source.name, source.url,
                                            target.name, target.url)
      poll_transfer('copy', xfer[:uuid])
    end
  end

  # pg:backups [subcommand]
  #
  # Interact with built-in backups. Without a subcommand, it lists all
  # available backups. The subcommands available are:
  #
  #  info BACKUP_ID                 # get information about a specific backup
  #  capture DATABASE               # capture a new backup
  #  restore [[BACKUP_ID] DATABASE] # restore a backup (default latest) to a database (default DATABASE_URL)
  #  public-url BACKUP_ID           # get secret but publicly accessible URL for BACKUP_ID to download it
  #    -q, --quiet                  #   Hide expiration message (for use in scripts)
  #  cancel [BACKUP_ID]             # cancel an in-progress backup or restore (default newest)
  #  delete BACKUP_ID               # delete an existing backup
  #  schedule DATABASE              # schedule nightly backups for given database
  #    --at '<hour>:00 <timezone>'  #   at a specific (24h clock) hour in the given timezone
  #  unschedule SCHEDULE            # stop nightly backups on this schedule
  #  schedules                      # list backup schedule
  def backups
    if args.count == 0
      list_backups
    else
      command = shift_argument
      case command
      when 'list' then list_backups
      when 'info' then backup_status
      when 'capture' then capture_backup
      when 'restore' then restore_backup
      when 'public-url' then public_url
      when 'cancel' then cancel_backup
      when 'delete' then delete_backup
      when 'schedule' then schedule_backups
      when 'unschedule' then unschedule_backups
      when 'schedules' then list_schedules
      else abort "Unknown pg:backups command: #{command}"
      end
    end
  end

  private

  MaybeAttachment = Struct.new(:name, :url, :attachment)

  def url_name(uri)
    "Database #{uri.path[1..-1]} on #{uri.host}:#{uri.port || 5432}"
  end

  def resolve_db_or_url(name_or_url, default=nil)
    if name_or_url =~ %r{postgres://}
      url = name_or_url
      uri = URI.parse(url)
      name = url_name(uri)
      MaybeAttachment.new(name, url, nil)
    else
      attachment = generate_resolver.resolve(name_or_url, default)
      name = attachment.config_var.sub(/^HEROKU_POSTGRESQL_/, '').sub(/_URL$/, '')
      MaybeAttachment.new(name, attachment.url, attachment)
    end
  end

  def arbitrary_app_db
    generate_resolver.all_databases.values.first
  end

  def transfer_name(transfer)
    old_pgb_name = transfer.has_key?(:options) && transfer[:options]["pgbackups_name"]

    if old_pgb_name
      "o#{old_pgb_name}"
    else
      transfer_num = transfer[:num]
      from_type, to_type = transfer[:from_type], transfer[:to_type]
      prefix = if from_type == 'pg_dump' && to_type != 'pg_restore'
                 transfer.has_key?(:schedule) ? 'a' : 'b'
               elsif from_type != 'pg_dump' && to_type == 'pg_restore'
                 'r'
               elsif from_type == 'pg_dump' && to_type == 'pg_restore'
                 'c'
               else
                 'b'
               end
      "#{prefix}#{format("%03d", transfer_num)}"
    end
  end

  def transfer_num(transfer_name)
    if /\A[abcr](\d+)\z/.match(transfer_name)
      $1.to_i
    elsif /\Ao[ab]\d+\z/.match(transfer_name)
      xfer = hpg_app_client(app).transfers.find do |t|
        transfer_name(t) == transfer_name
      end
      xfer[:num] unless xfer.nil?
    end
  end

  def transfer_status(t)
    if t[:finished_at] && t[:succeeded]
      "Finished #{t[:finished_at]}"
    elsif t[:finished_at] && !t[:succeeded]
      "Failed #{t[:finished_at]}"
    elsif t[:started_at]
      "Running (processed #{size_pretty(t[:processed_bytes])})"
    else
      "Pending"
    end
  end

  def size_pretty(bytes)
    suffixes = [
      ['B', 1],
      ['kB', 1_000],
      ['MB', 1_000_000],
      ['GB', 1_000_000_000],
      ['TB', 1_000_000_000_000] # (ohdear)
    ]
    suffix, multiplier = suffixes.find do |k,v|
      normalized = bytes / v.to_f
      normalized >= 0 && normalized < 1_000
    end
    if suffix.nil?
      return bytes
    end
    normalized = bytes / multiplier.to_f
    num_digits = case
                 when normalized >= 100 then '0'
                 when normalized >= 10 then '1'
                 else '2'
                 end
    fmt_str = "%.#{num_digits}f#{suffix}"
    format(fmt_str, normalized)
  end

  def list_backups
    validate_arguments!
    transfers = hpg_app_client(app).transfers

    display "=== Backups"
    display_backups = transfers.select do |b|
      b[:from_type] == 'pg_dump' && b[:to_type] == 'gof3r'
    end.sort_by { |b| b[:created_at] }.reverse.map do |b|
      {
        "id" => transfer_name(b),
        "created_at" => b[:created_at],
        "status" => transfer_status(b),
        "size" => size_pretty(b[:processed_bytes]),
        "database" => b[:from_name] || 'UNKNOWN'
      }
    end
    if display_backups.empty?
      display("No backups. Capture one with `heroku pg:backups capture`.")
    else
      display_table(
        display_backups,
        %w(id created_at status size database),
        ["ID", "Backup Time", "Status", "Size", "Database"]
      )
    end

    display "\n=== Restores"
    display_restores = transfers.select do |r|
      r[:from_type] != 'pg_dump' && r[:to_type] == 'pg_restore'
    end.sort_by { |r| r[:created_at] }.reverse.first(10).map do |r|
      {
        "id" => transfer_name(r),
        "created_at" => r[:created_at],
        "status" => transfer_status(r),
        "size" => size_pretty(r[:processed_bytes]),
        "database" => r[:to_name] || 'UNKNOWN'
      }
    end
    if display_restores.empty?
      display("No restores found. Use `heroku pg:backups restore` to restore a backup")
    else
      display_table(
        display_restores,
        %w(id created_at status size database),
        ["ID", "Restore Time", "Status", "Size", "Database"]
      )
    end

    display "\n=== Copies"
    display_restores = transfers.select do |r|
      r[:from_type] == 'pg_dump' && r[:to_type] == 'pg_restore'
    end.sort_by { |r| r[:created_at] }.reverse.first(10).map do |r|
      {
        "id" => transfer_name(r),
        "created_at" => r[:created_at],
        "status" => transfer_status(r),
        "size" => size_pretty(r[:processed_bytes]),
        "to_database" => r[:to_name] || 'UNKNOWN',
        "from_database" => r[:from_name] || 'UNKNOWN'
      }
    end
    if display_restores.empty?
      display("No copies found. Use `heroku pg:copy` to copy a database to another")
    else
      display_table(
        display_restores,
        %w(id created_at status size from_database to_database),
        ["ID", "Restore Time", "Status", "Size", "From Database", "To Database"]
      )
    end
  end

  def backup_status
    backup_name = shift_argument
    validate_arguments!
    verbose = true

    client = hpg_app_client(app)
    backup = if backup_name.nil?
               backups = client.transfers
               last_backup = backups.select do |b|
                 b[:from_type] == 'pg_dump' && b[:to_type] == 'gof3r'
               end.sort_by { |b| b[:created_at] }.last
               if last_backup.nil?
                 error("No backups. Capture one with `heroku pg:backups capture`.")
               else
                 if verbose
                   client.transfers_get(last_backup[:num], verbose)
                 else
                   last_backup
                 end
               end
             else
               backup_num = transfer_num(backup_name)
               if backup_num.nil?
                 error("No such backup: #{backup_num}")
               end
               client.transfers_get(backup_num, verbose)
             end
    status = if backup[:succeeded]
               "Completed Successfully"
             elsif backup[:canceled_at]
               "Canceled"
             elsif backup[:finished_at]
               "Failed"
             elsif backup[:started_at]
               "Running"
             else
               "Pending"
             end
    type = if backup[:schedule]
             "Scheduled"
           else
             "Manual"
           end

    backup_name = transfer_name(backup)
    display <<-EOF
=== Backup info: #{backup_name}
Database:    #{backup[:from_name]}
EOF
    if backup[:started_at]
      display <<-EOF
Started:     #{backup[:started_at]}
EOF
    end
    if backup[:finished_at]
      display <<-EOF
Finished:    #{backup[:finished_at]}
EOF
    end
    display <<-EOF
Status:      #{status}
Type:        #{type}
EOF
    backup_size = backup[:processed_bytes]
    orig_size = backup[:source_bytes] || 0
    if orig_size > 0
      compress_str = ""
      unless backup[:finished_at].nil?
        compression_pct = if backup_size > 0
                            [((orig_size - backup_size).to_f / orig_size * 100)
                               .round, 0].max
                          else
                            0
                          end
        compress_str = " (#{compression_pct}% compression)"
      end
      display <<-EOF
Original DB Size: #{size_pretty(orig_size)}
Backup Size:      #{size_pretty(backup_size)}#{compress_str}
EOF
    else
      display <<-EOF
Backup Size: #{size_pretty(backup_size)}
EOF
    end
    if verbose
      display "=== Backup Logs"
      backup[:logs].each do |item|
        display "#{item['created_at']}: #{item['message']}"
      end
    end
  end

  def capture_backup
    db = shift_argument
    attachment = generate_resolver.resolve(db, "DATABASE_URL")
    validate_arguments!

    backup = hpg_client(attachment).backups_capture
    display <<-EOF
Use Ctrl-C at any time to stop monitoring progress; the backup
will continue running. Use heroku pg:backups info to check progress.
Stop a running backup with heroku pg:backups cancel.

#{attachment.name} ---backup---> #{transfer_name(backup)}

EOF
    poll_transfer('backup', backup[:uuid])
  end

  def restore_backup
    # heroku pg:backups restore [[backup_id] database]
    db = nil
    restore_from = :latest

    # N.B.: we have to account for the command argument here
    if args.count == 2
      db = shift_argument
    elsif args.count == 3
      restore_from = shift_argument
      db = shift_argument
    end

    attachment = generate_resolver.resolve(db, "DATABASE_URL")
    validate_arguments!

    restore_url = nil
    if restore_from =~ %r{\Ahttps?://}
      restore_url = restore_from
    else
      # assume we're restoring from a backup
      backup_name = restore_from
      backups = hpg_app_client(app).transfers.select do |b|
        b[:from_type] == 'pg_dump' && b[:to_type] == 'gof3r'
      end
      backup = if backup_name == :latest
                 backups.select { |b| b[:succeeded] }
                   .sort_by { |b| b[:finished_at] }.last
               else
                 backups.find { |b| transfer_name(b) == backup_name }
               end
      if backups.empty?
        abort("No backups. Capture one with `heroku pg:backups capture`.")
      elsif backup.nil?
        abort("Backup #{backup_name} not found.")
      elsif !backup[:succeeded]
        abort("Backup #{backup_name} did not complete successfully; cannot restore it.")
      end
      restore_url = backup[:to_url]
    end

    if confirm_command
      restore = hpg_client(attachment).backups_restore(restore_url)
      display <<-EOF
Use Ctrl-C at any time to stop monitoring progress; the backup
will continue restoring. Use heroku pg:backups to check progress.
Stop a running restore with heroku pg:backups cancel.

#{transfer_name(restore)} ---restore---> #{attachment.name}

EOF
      poll_transfer('restore', restore[:uuid])
    end
  end

  def poll_transfer(action, transfer_id)
    # pending, running, complete--poll endpoint to get
    backup = nil
    ticks = 0
    failed_count = 0
    begin
      begin
        backup = hpg_app_client(app).transfers_get(transfer_id)
        failed_count = 0
        status = if backup[:started_at]
                   "Running... #{size_pretty(backup[:processed_bytes])}"
                 else
                   "Pending... #{spinner(ticks)}"
                 end
        redisplay status
        ticks += 1
      rescue RestClient::Exception
        backup = {}
        failed_count += 1
        if failed_count > 120
          raise
        end
      end
      sleep 1
    end until backup[:finished_at]
    if backup[:succeeded]
      redisplay "#{action.capitalize} completed\n"
    else
      # TODO: better errors for
      #  - db not online (/name or service not known/)
      #  - bad creds (/psql: FATAL:/???)
      redisplay <<-EOF
An error occurred and your backup did not finish.

Please run `heroku pg:backups info #{transfer_name(backup)}` for details.

EOF
    end
  end

  def delete_backup
    backup_name = shift_argument
    validate_arguments!

    if confirm_command
      backup_num = transfer_num(backup_name)
      if backup_num.nil?
        error("No such backup: #{backup_num}")
      end
      hpg_app_client(app).transfers_delete(backup_num)
      display "Deleted #{backup_name}"
    end
  end

  def public_url
    backup_name = shift_argument
    validate_arguments!

    backup_num = nil
    client = hpg_app_client(app)
    if backup_name
      backup_num = transfer_num(backup_name)
      if backup_num.nil?
        error("No such backup: #{backup_num}")
      end
    else
      last_successful_backup = client.transfers.select do |xfer|
        xfer[:succeeded] && xfer[:to_type] == 'gof3r'
      end.sort_by { |b| b[:created_at] }.last
      if last_successful_backup.nil?
        error("No backups. Capture one with `heroku pg:backups capture`.")
      else
        backup_num = last_successful_backup[:num]
      end
    end

    url_info = client.transfers_public_url(backup_num)
    if $stdout.tty? && !options[:quiet]
      display <<-EOF
The following URL will expire at #{url_info[:expires_at]}:
  "#{url_info[:url]}"
EOF
    else
      display url_info[:url]
    end
  end

  def cancel_backup
    backup_name = shift_argument
    validate_arguments!

    client = hpg_app_client(app)

    transfer = if backup_name
                 backup_num = transfer_num(backup_name)
                 if backup_num.nil?
                   error("No such backup/restore: #{backup_name}")
                 else
                   client.transfers_get(backup_num)
                 end
               else
                 last_transfer = client.transfers.sort_by { |b| b[:created_at] }.reverse.find { |b| b[:finished_at].nil? }
                 if last_transfer.nil?
                   error("No active backups/restores")
                 else
                   last_transfer
                 end
               end

    client.transfers_cancel(transfer[:uuid])
    display "Canceled #{transfer_name(transfer)}"
  end

  def schedule_backups
    db = shift_argument
    validate_arguments!
    at = options[:at] || '04:00 UTC'
    schedule_opts = parse_schedule_time(at)

    resolver = generate_resolver
    attachment = resolver.resolve(db, "DATABASE_URL")

    # N.B.: we need to resolve the name to find the right database,
    # but we don't want to resolve it to the canonical name, so that,
    # e.g., names like FOLLOWER_URL work. To do this, we look up the
    # app config vars and re-find one that looks like the user's
    # requested name.
    db_name, alias_url = resolver.app_config_vars.find { |k,_| k =~ /#{db}/i }
    if attachment.url != alias_url
      error("Could not find database to schedule for backups. Try using its full name.")
    end

    schedule_opts[:schedule_name] = db_name

    hpg_client(attachment).schedule(schedule_opts)
    display "Scheduled automatic daily backups at #{at} for #{attachment.name}"
  end

  def unschedule_backups
    db = shift_argument
    validate_arguments!

    if db.nil?
      # try to provide a more informative error message, but rescue to
      # a generic error message in case things go poorly
      begin
        attachment = arbitrary_app_db
        schedules = hpg_client(attachment).schedules
        schedule_names = schedules.map { |s| s[:name] }.join(", ")
        abort("Must specify schedule to cancel: existing schedules are #{schedule_names}")
      rescue StandardError
        abort("Must specify schedule to cancel. Run `heroku help pg:backups` for usage information.")
      end
    end

    attachment = generate_resolver.resolve(db, "DATABASE_URL")

    schedule = hpg_client(attachment).schedules.find do |s|
      # s[:name] is HEROKU_POSTGRESQL_COLOR_URL
      s[:name] =~ /#{db}/i
    end

    if schedule.nil?
      display "No automatic daily backups for #{attachment.name} found"
    else
      hpg_client(attachment).unschedule(schedule[:uuid])
      display "Stopped automatic daily backups for #{attachment.name}"
    end
  end

  def list_schedules
    validate_arguments!
    attachment = arbitrary_app_db

    schedules = hpg_client(attachment).schedules
    if schedules.empty?
      display "No backup schedules found. Use `heroku pg:backups schedule` to set one up."
    else
      display "=== Backup Schedules"
      schedules.each do |s|
        display "#{s[:name]}: daily at #{s[:hour]}:00 (#{s[:timezone]})"
      end
    end
  end

  def hpg_app_client(app_name)
    Heroku::Client::HerokuPostgresqlApp.new(app_name)
  end

  def parse_schedule_time(time_str)
    hour, tz = time_str.match(/([0-2][0-9]):00 (.*)/) && [ $1, $2 ]
    if hour.nil? || tz.nil?
      abort("Invalid schedule format: expected '<hour>:00 <timezone>'")
    end
    # do-what-i-mean remapping, since transferatu is (rightfully) picky
    remap_tzs = {
                 'PST' => 'America/Los_Angeles',
                 'PDT' => 'America/Los_Angeles',
                 'MST' => 'America/Boise',
                 'MDT' => 'America/Boise',
                 'CST' => 'America/Chicago',
                 'CDT' => 'America/Chicago',
                 'EST' => 'America/New_York',
                 'EDT' => 'America/New_York'
                }
    if remap_tzs.has_key? tz.upcase
      tz = remap_tzs[tz.upcase]
    end
    { :hour => hour, :timezone => tz }
  end
end
