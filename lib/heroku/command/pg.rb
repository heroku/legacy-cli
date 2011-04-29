require "heroku/command/base"
require "heroku/pgutils"
require "heroku-postgresql/client"

module Heroku::Command

  # manage heroku postgresql databases
  class Pg < BaseWithApp

    include PgUtils

    # pg:info
    #
    # show database status
    #
    # -d, --db DATABASE # the config var that contains the database URL you'd like to use
    #
    def info
      (name, database) = extract_db(:include_shared => true)

      unless name.match("HEROKU_POSTGRESQL")
        attrs = heroku.info(app)
        display("=== #{app} database #{name}")
        display_info("Data size",
          "#{size_format(attrs[:database_size].to_i)}")
        return
      end

      with_heroku_postgresql_database do |name, url|
        database = heroku_postgresql_client(url).get_database
        display("=== #{app} database #{name}")

        display_info("State",
          "#{database[:state]} for " +
          "#{delta_format(Time.parse(database[:state_updated_at]))}")

        if database[:num_bytes] && database[:num_tables]
          display_info("Data size",
            "#{size_format(database[:num_bytes])} in " +
            "#{database[:num_tables]} table#{database[:num_tables] == 1 ? "" : "s"}")
        end

        if @heroku_postgresql_url
          display_info("URL", @heroku_postgresql_url)
        end

        if version = database[:postgresql_version]
          display_info("PG version", version)
        end

        display_info("Born", time_format(database[:created_at]))
        display_info("Mem Used", "%0.2f %" % database[:mem_percent_used]) unless [nil, ""].include? database[:mem_percent_used]
        display_info("CPU Used", "%0.2f %" % (100 - database[:cpu_idle].to_f)) unless [nil, ""].include? database[:cpu_idle]
      end
    end

    # pg:promote
    #
    # promote a database identifier to DATABASE_URL
    #
    # -d, --db DATABASE # the config var that contains the database URL you'd like to use
    #
    def promote
      db_id = extract_option("--db")
      url = config_vars[db_id]
      abort(" !   Usage: heroku pg:promote --db <DATABASE>") unless url

      # look up the true name of the database, avoiding "DATABASE_URL" unless it's the only option
      name = config_vars.reject { |(var, val)| var == "DATABASE_URL" }.invert[url] || "DATABASE_URL"

      if db_id == "DATABASE_URL"
        abort(" !  Promoting DATABASE_URL to DATABASE_URL has no effect.")
        return
      end

      abort(" !   DATABASE_URL is already set to #{name}.") if url == config_vars["DATABASE_URL"]

      display "Setting config variable DATABASE_URL to #{name}", false
      return unless confirm_command
      display "... "

      heroku.add_config_vars(app, {"DATABASE_URL" => url})

      display "done"

      display "DATABASE_URL (#{name})     => #{url}"
      display
    end

    # pg:reset
    #
    # delete all data in the specified database
    #
    # -d, --db DATABASE # the config var that contains the database URL you'd like to use
    #
    def reset
      db_id = extract_option("--db")

      (name, url, primary) = resolve_db_id(db_id, :usage_message => " !   Usage: heroku pg:reset --db <DATABASE>")

      redisplay "Resetting #{name}#{primary ? ' (DATABASE_URL)' : ''}", false


      if confirm_command
        display "... ", false
        # support legacy database reset
        if name == "SHARED_DATABASE_URL"
          heroku.database_reset(app)
        else
          heroku_postgresql_client(url).reset
        end
        display "done"
      end
    end

    # pg:wait
    #
    # monitor a database currently being created, exit when complete
    #
    # -d, --db DATABASE # the config var that contains the database URL you'd like to use
    #
    def wait
      # TODO: this should check that no heroku database is pre-running
      with_heroku_postgresql_database do |name, url|
        ticking do |ticks|
          database = heroku_postgresql_client(url).get_database
          state = database[:state]
          if state == "available"
            redisplay("The database is now ready", true)
            break
          elsif state == "deprovisioned"
            redisplay("The database has been destroyed", true)
            break
          elsif state == "failed"
            redisplay("The database encountered an error", true)
            break
          else
            redisplay("#{state.capitalize} database #{spinner(ticks)}", false)
          end
        end
      end
    end

    # pg:psql
    #
    # open a psql shell to the database (dedicated only)
    #
    # -d, --db DATABASE # the config var that contains the database URL you'd like to use
    #
    def psql
      with_psql_binary do
        with_heroku_postgresql_database do |name, url|
          database = heroku_postgresql_client(url).get_database
          abort " !  The database is not available" unless database[:state] == "available"
          display("Connecting to database for app #{app} ...")
          heroku_postgresql_client(url).ingress
          url = URI.parse(url)
          ENV["PGPASSWORD"] = url.password
          cmd = "psql -U #{url.user} -h #{url.host} #{url.path[1..-1]}"
          system(cmd)
        end
      end
    end

    # pg:ingress
    #
    # allow direct connections to the database from this IP for one minute (dedicated only)
    #
    # -d, --db DATABASE # the config var that contains the database URL you'd like to use
    #
    def ingress
      with_heroku_postgresql_database do |name, url|
        database = heroku_postgresql_client(url).get_database
        abort "The database is not available" unless database[:state] == "available"
        redisplay("Granting ingress to #{name} for 60s...")
        heroku_postgresql_client(url).ingress
        url = URI.parse(url)
        redisplay("Granting ingress to #{name} for 60s... done\n")
        display("Connection info string:")
        display("   \"dbname=#{url.path[1..-1]} host=#{url.host} user=#{url.user} password=#{url.password}\"")
      end
    end

    # pg:backups
    #
    # list legacy postgres backups
    #
    # DEPRECATED: see http://docs.heroku.com/pgbackups#legacy
    #
    # -d, --db DATABASE # the config var that contains the database URL you'd like to use
    #
    def backups
      display "This feature has been deprecated. Please see http://docs.heroku.com/pgbackups#legacy\n"
      backups = heroku_postgresql_client.get_backups
      valid_backups = backups.select { |b| !b[:error_at] }
      if backups.empty?
        display("App #{app} has no database backups")
      else
        name_width = backups.map { |b| b[:name].length }.max
        backups.sort_by { |b| b[:started_at] }.reverse.each do |b|
          state =
            if b[:finished_at]
              size_format(b[:size_compressed])
            elsif prog = b[:progress]
              "#{prog.last.first.capitalize}ing"
            else
              "Pending"
            end
          display(format("%-#{name_width}s  %s", b[:name], state))
        end
      end
    end

    protected

    def heroku_postgresql_var_names
      pg_config_var_names.select { |n| n.match("HEROKU_POSTGRESQL") }
    end

    def config_vars
      @config_vars ||= heroku.config_vars(app)
    end

    def extract_db(opts={})
      db_id = extract_option("--db")
      (name, database) = resolve_db_id(db_id, :default => 'DATABASE_URL') # get DATABASE_URL first

      return name, database if opts[:include_shared] || name.match("HEROKU_POSTGRESQL")

      (name, database) = resolve_db_id(db_id, :default => heroku_postgresql_var_names.first) # get any HEROKU_POSTGRESQL_*_URL next
      return name, database if name.match("HEROKU_POSTGRESQL")
    end

    def with_heroku_postgresql_database
      if !heroku_postgresql_var_names
        abort("The addon is not installed for the app #{app}")
      end

      (name, database) = extract_db
      abort " !  This command is only available for addon databases." unless name

      yield name, database
    end

    def heroku_postgresql_client(url)
      uri = URI.parse(url)
      HerokuPostgresql::Client.new(uri.user, uri.password, uri.path[1..-1])
    end

    def with_optionally_named_backup
      backup_name = args.first && args.first.strip
      backup = backup_name ? heroku_postgresql_client.get_backup(backup_name) :
                             heroku_postgresql_client.get_backup_recent
      if backup[:finished_at]
        yield(backup)
      elsif backup[:error_at]
        display("Backup #{backup[:name]} did not complete successfully")
      else
        display("Backup #{backup[:name]} has not yet completed")
      end
    end

    def restore_with(restore_param)
      restore = heroku_postgresql_client.create_restore(restore_param)
      restore_id = restore[:id]
      ticking do |ticks|
        restore = heroku_postgresql_client.get_restore(restore_id)
        display_progress(restore[:progress], ticks)
        if restore[:error_at]
          display("\nAn error occured while restoring the backup")
          display(restore[:log])
          break
        elsif restore[:finished_at]
          display("Restore complete")
          break
        end
      end
    end

    def with_psql_binary
      if !has_binary?("psql")
        display("Please install the 'psql' command line tool")
      else
        yield
      end
    end

    def with_download_binary
      if has_binary?("curl")
        yield(:curl)
      elsif has_binary?("wget")
        yield(:wget)
      else
        display("Please install either the 'curl' or 'wget' command line tools")
      end
    end

    def exec_download(from, to, binary)
      if binary == :curl
        system("curl -o \"#{to}\" \"#{from}\"")
      elsif binary == :wget
        system("wget -O \"#{to}\" --no-check-certificate \"#{from}\"")
      else
        display("Unrecognized binary #{binary}")
      end
    end

    def ticking
      ticks = 0
      loop do
        yield(ticks)
        ticks +=1
        sleep 1
      end
    end

    def display_progress_part(part, ticks)
      task, amount = part
      if amount == "start"
        redisplay(format("%-10s ... %s", task.capitalize, spinner(ticks)))
        @last_amount = 0
      elsif amount.is_a?(Fixnum)
        redisplay(format("%-10s ... %s  %s", task.capitalize, size_format(amount), spinner(ticks)))
        @last_amount = amount
      elsif amount == "finish"
        redisplay(format("%-10s ... %s, done", task.capitalize, size_format(@last_amount)), true)
      end
    end

    def display_progress(progress, ticks)
      progress ||= []
      new_progress = ((progress || []) - (@seen_progress || []))
      if !new_progress.empty?
        new_progress.each { |p| display_progress_part(p, ticks) }
      elsif !progress.empty? && progress.last[0] != "finish"
        display_progress_part(progress.last, ticks)
      end
      @seen_progress = progress
    end

    def delta_format(start, finish = Time.now)
      secs = (finish.to_i - start.to_i).abs
      mins = (secs/60).round
      hours = (mins / 60).round
      days = (hours / 24).round
      weeks = (days / 7).round
      months = (weeks / 4.3).round
      years = (months / 12).round
      if years > 0
        "#{years} yr"
      elsif months > 0
        "#{months} mo"
      elsif weeks > 0
        "#{weeks} wk"
      elsif days > 0
        "#{days}d"
      elsif hours > 0
        "#{hours}h"
      elsif mins > 0
        "#{mins}m"
      else
        "#{secs}s"
      end
    end

    KB = 1024      unless self.const_defined?(:KB)
    MB = 1024 * KB unless self.const_defined?(:MB)
    GB = 1024 * MB unless self.const_defined?(:GB)

    def size_format(bytes)
      return "#{bytes}B" if bytes < KB
      return "#{(bytes / KB)}KB" if bytes < MB
      return format("%.1fMB", (bytes.to_f / MB)) if bytes < GB
      return format("%.2fGB", (bytes.to_f / GB))
    end

    def time_format(time)
      time = Time.parse(time) if time.is_a?(String)
      time.strftime("%Y-%m-%d %H:%M %Z")
    end

    def timestamp_name
      Time.now.strftime("%Y-%m-%d-%H:%M:%S")
    end

    def has_binary?(binary)
      `which #{binary}` != ""
    end
  end
end
