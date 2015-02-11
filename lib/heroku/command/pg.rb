require "thread"

require "heroku/client/heroku_postgresql"
require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"
require "heroku/helpers/pg_dump_restore"

require "heroku/helpers/pg_diagnose"

# manage heroku-postgresql databases
#
class Heroku::Command::Pg < Heroku::Command::Base
  module Hooks
    extend self
    def set_commands(shorthand)
      ''
    end
  end

  include Heroku::Helpers::HerokuPostgresql
  include Heroku::Helpers::PgDiagnose

  # pg
  #
  # list databases for an app
  #
  def index
    requires_preauth
    validate_arguments!

    if hpg_databases_with_info.empty?
      display("#{app} has no heroku-postgresql databases.")
    else
      hpg_databases_with_info.keys.sort.each do |name|
        display_db name, hpg_databases_with_info[name]
      end
    end
  end

  # pg:info [DATABASE]
  #
  #   -x, --extended  # Show extended information
  #
  # display database information
  #
  # If DATABASE is not specified, displays all databases
  #
  def info
    db = shift_argument
    validate_arguments!
    requires_preauth

    if db
      @resolver = generate_resolver
      attachment = @resolver.resolve(db)
      display_db attachment.display_name, hpg_info(attachment, options[:extended])
    else
      index
    end
  end

  # pg:diagnose [DATABASE|REPORT_ID]
  #
  # run diagnostics report on DATABASE
  #
  # defaults to DATABASE_URL databases if no DATABASE is specified
  # if REPORT_ID is specified instead, a previous report is displayed
  def diagnose
    requires_preauth
    db_id = shift_argument
    run_diagnose(db_id)
  end

  # pg:promote DATABASE
  #
  # sets DATABASE as your DATABASE_URL
  #
  def promote
    requires_preauth
    unless db = shift_argument
      error("Usage: heroku pg:promote DATABASE\nMust specify DATABASE to promote.")
    end
    validate_arguments!

    attachment = generate_resolver.resolve(db)

    action "Promoting #{attachment.display_name} to DATABASE_URL" do
      hpg_promote(attachment.url)
    end
  end

  # pg:psql [DATABASE]
  #
  #  -c, --command COMMAND      # optional SQL command to run
  #
  # open a psql shell to the database
  #
  # defaults to DATABASE_URL databases if no DATABASE is specified
  #
  def psql
    requires_preauth
    attachment = generate_resolver.resolve(shift_argument, "DATABASE_URL")
    validate_arguments!

    uri = URI.parse( attachment.url )
    begin
      ENV["PGPASSWORD"] = uri.password
      ENV["PGSSLMODE"]  = 'require'
      if command = options[:command]
        command = %Q(-c "#{command}")
      end

      shorthand = "#{attachment.app}::#{attachment.name.sub(/^HEROKU_POSTGRESQL_/,'').gsub(/\W+/, '-')}"
      set_commands = Hooks.set_commands(shorthand)
      prompt_expr = "#{shorthand}%R%# "
      prompt_flags = %Q(--set "PROMPT1=#{prompt_expr}" --set "PROMPT2=#{prompt_expr}")
      puts "---> Connecting to #{attachment.display_name}"
      exec "psql -U #{uri.user} -h #{uri.host} -p #{uri.port || 5432} #{set_commands} #{prompt_flags} #{command} #{uri.path[1..-1]}"
    rescue Errno::ENOENT
      output_with_bang "The local psql command could not be located"
      output_with_bang "For help installing psql, see http://devcenter.heroku.com/articles/local-postgresql"
      abort
    end
  end

  # pg:reset DATABASE
  #
  # delete all data in DATABASE
  #
  def reset
    requires_preauth
    unless db = shift_argument
      error("Usage: heroku pg:reset DATABASE\nMust specify DATABASE to reset.")
    end
    validate_arguments!

    resolver = generate_resolver
    attachment = resolver.resolve(db)
    @app = resolver.app_name if @app.nil?

    return unless confirm_command

    action("Resetting #{attachment.display_name}") do
      hpg_client(attachment).reset
    end
  end

  # pg:unfollow REPLICA
  #
  # stop a replica from following and make it a read/write database
  #
  def unfollow
    requires_preauth
    unless db = shift_argument
      error("Usage: heroku pg:unfollow REPLICA\nMust specify REPLICA to unfollow.")
    end
    validate_arguments!

    resolver = generate_resolver
    replica = resolver.resolve(db)
    @app = resolver.app_name if @app.nil?

    replica_info = hpg_info(replica)

    unless replica_info[:following]
      error("#{replica.display_name} is not following another database.")
    end
    origin_url = replica_info[:following]
    origin_name = resolver.database_name_from_url(origin_url)

    output_with_bang "#{replica.display_name} will become writable and no longer"
    output_with_bang "follow #{origin_name}. This cannot be undone."
    return unless confirm_command

    action "Unfollowing #{replica.display_name}" do
      hpg_client(replica).unfollow
    end
  end

  # pg:wait [DATABASE]
  #
  # monitor database creation, exit when complete
  #
  # defaults to all databases if no DATABASE is specified
  #
  def wait
    requires_preauth
    db = shift_argument
    validate_arguments!

    if db
      wait_for generate_resolver.resolve(db)
    else
      generate_resolver.all_databases.values.each do |attach|
        wait_for(attach)
      end
    end
  end

  # pg:credentials DATABASE
  #
  # display the DATABASE credentials.
  #
  #   --reset  # Reset credentials on the specified database.
  #
  def credentials
    requires_preauth
    unless db = shift_argument
      error("Usage: heroku pg:credentials DATABASE\nMust specify DATABASE to display credentials.")
    end
    validate_arguments!

    attachment = generate_resolver.resolve(db)

    if options[:reset]
      action "Resetting credentials for #{attachment.display_name}" do
        hpg_client(attachment).rotate_credentials
      end
      if attachment.primary_attachment?
        attachment = generate_resolver.resolve(db)
        action "Promoting #{attachment.display_name}" do
          hpg_promote(attachment.url)
        end
      end
    else
      uri = URI.parse( attachment.url )
      display "Connection info string:"
      display "   \"dbname=#{uri.path[1..-1]} host=#{uri.host} port=#{uri.port || 5432} user=#{uri.user} password=#{uri.password} sslmode=require\""
      display "Connection URL:"
      display "    " + attachment.url

    end
  end

  # pg:ps [DATABASE]
  #
  # view active queries with execution time
  #
  def ps
    requires_preauth
    sql = %Q(
    SELECT
      #{pid_column},
      #{"state," if nine_two?}
      application_name AS source,
      age(now(),xact_start) AS running_for,
      waiting,
      #{query_column} AS query
     FROM pg_stat_activity
     WHERE
       #{query_column} <> '<insufficient privilege>'
       #{
          if nine_two?
            "AND state <> 'idle'"
          else
            "AND current_query <> '<IDLE>'"
          end
       }
       AND #{pid_column} <> pg_backend_pid()
       ORDER BY query_start DESC
     )

    puts exec_sql(sql)
  end

  # pg:kill procpid [DATABASE]
  #
  # kill a query
  #
  # -f,--force  # terminates the connection in addition to cancelling the query
  #
  def kill
    requires_preauth
    procpid = shift_argument
    output_with_bang "procpid to kill is required" unless procpid && procpid.to_i != 0
    procpid = procpid.to_i

    cmd = options[:force] ? 'pg_terminate_backend' : 'pg_cancel_backend'
    sql = %Q(SELECT #{cmd}(#{procpid});)

    puts exec_sql(sql)
  end

  # pg:killall [DATABASE]
  #
  # terminates ALL connections
  #
  def killall
    requires_preauth
    db = args.first
    attachment = generate_resolver.resolve(db, "DATABASE_URL")
    client = hpg_client(attachment)
    client.connection_reset
    display "Connections terminated"
  rescue StandardError
    # fall back to original mechanism if calling the reset endpoint
    # fails
    sql = %Q(
      SELECT pg_terminate_backend(#{pid_column})
      FROM pg_stat_activity
      WHERE #{pid_column} <> pg_backend_pid()
      AND #{query_column} <> '<insufficient privilege>'
    )

    puts exec_sql(sql)
  end


  # pg:push <SOURCE_DATABASE> <REMOTE_TARGET_DATABASE>
  #
  # push from SOURCE_DATABASE to REMOTE_TARGET_DATABASE
  # REMOTE_TARGET_DATABASE must be empty.
  #
  # SOURCE_DATABASE must be either the name of a database
  # existing on your localhost or the fully qualified URL of
  # a remote database.
  def push
    requires_preauth
    local, remote = shift_argument, shift_argument
    unless [remote, local].all?
      Heroku::Command.run(current_command, ['--help'])
      exit(1)
    end

    target_uri = resolve_heroku_url(remote)
    source_uri = parse_db_url(local)

    pgdr = PgDumpRestore.new(
      source_uri,
      target_uri,
      self)

    pgdr.execute
  end

  # pg:pull <REMOTE_SOURCE_DATABASE> <TARGET_DATABASE>
  #
  # pull from REMOTE_SOURCE_DATABASE to TARGET_DATABASE
  # TARGET_DATABASE must not already exist.
  #
  # TARGET_DATABASE will be created locally if it's a database name
  # or remotely if it's a fully qualified URL.
  def pull
    requires_preauth
    remote, local = shift_argument, shift_argument
    unless [remote, local].all?
      Heroku::Command.run(current_command, ['--help'])
      exit(1)
    end

    source_uri = resolve_heroku_url(remote)
    target_uri = parse_db_url(local)

    pgdr = PgDumpRestore.new(
      source_uri,
      target_uri,
      self)

    pgdr.execute
  end


  # pg:maintenance <info|run|set-window> <DATABASE>
  #
  #  manage maintenance for <DATABASE>
  #  info               # show current maintenance information
  #  run                # start maintenance
  #    -f, --force      #   run pg:maintenance without entering application maintenance mode
  #  window="<window>"  # set weekly UTC maintenance window for DATABASE
  #                     # eg: `heroku pg:maintenance window="Sunday 14:30"`
  def maintenance
    requires_preauth
    mode_with_argument = shift_argument || ''
    mode, mode_argument = mode_with_argument.split('=')

    db   = shift_argument
    no_maintenance = options[:force]
    if mode.nil? || db.nil? || !(%w[info run window].include? mode)
      Heroku::Command.run(current_command, ["--help"])
      exit(1)
    end

    resolver = generate_resolver
    attachment = resolver.resolve(db)
    if attachment.starter_plan?
      error("pg:maintenance is not available for hobby-tier databases")
    end

    case mode
    when 'info'
      response = hpg_client(attachment).maintenance_info
      display response[:message]
    when 'run'
      if in_maintenance?(resolver.app_name) || no_maintenance
        response = hpg_client(attachment).maintenance_run
        display response[:message]
      else
        error("Application must be in maintenance mode or --force flag must be used")
      end
    when 'window'
      unless mode_argument =~ /\A[A-Za-z]{3,10} \d\d?:[03]0\z/
      error('Maintenance windows must be "Day HH:MM", where MM is 00 or 30.')
      end

      response = hpg_client(attachment).maintenance_window_set(mode_argument)
      display "Maintenance window for #{attachment.display_name} set for #{response[:window]}."
    end
  end


  # pg:upgrade REPLICA
  #
  # unfollow a database and upgrade it to the latest PostgreSQL version
  #
  def upgrade
    requires_preauth
    unless db = shift_argument
      error("Usage: heroku pg:upgrade REPLICA\nMust specify REPLICA to upgrade.")
    end
    validate_arguments!

    resolver = generate_resolver
    replica = resolver.resolve(db)
    @app = resolver.app_name if @app.nil?

    replica_info = hpg_info(replica)

    if replica.starter_plan?
      error("pg:upgrade is only available for follower production databases.")
    end

    upgrade_status = hpg_client(replica).upgrade_status

    if upgrade_status[:error]
      output_with_bang "There were problems upgrading #{replica.resource_name}"
      output_with_bang upgrade_status[:error]
    else
      origin_url = replica_info[:following]
      origin_name = resolver.database_name_from_url(origin_url)

      output_with_bang "#{replica.resource_name} will be upgraded to a newer PostgreSQL version,"
      output_with_bang "stop following #{origin_name}, and become writable."
      output_with_bang "Use `heroku pg:wait` to track status"
      output_with_bang "\nThis cannot be undone."
      return unless confirm_command

      action "Requesting upgrade" do
        hpg_client(replica).upgrade
      end
    end
  end



private

  def resolve_heroku_url(remote)
    generate_resolver.resolve(remote).url
  end

  def generate_resolver
    app_name = app rescue nil # will raise if no app, but calling app reads in arguments
    Resolver.new(app_name, api)
  end

  # Parse string database parameter and return string database URL.
  #
  # @param db_string [String] The local database name or a full connection URL, e.g. `my_db` or `postgres://user:pass@host:5432/my_db`
  # @return [String] A full database connection URL.
  def parse_db_url(db_string)
    return db_string if db_string =~ %r(://)

    "postgres:///#{db_string}"
  end

  def display_db(name, db)
    styled_header(name)

    if db
      dsphash = db[:info].inject({}) do |hash, item|
        hash.update(item["name"] => hpg_info_display(item))
      end
      dspkeys = db[:info].map {|item| item['name']}

      styled_hash(dsphash, dspkeys)
    else
      styled_hash("Error" => "Not Found")
    end

    display
  end

  def hpg_client(attachment)
    Heroku::Client::HerokuPostgresql.new(attachment)
  end

  def hpg_databases_with_info
    return @hpg_databases_with_info if @hpg_databases_with_info

    @resolver = generate_resolver
    dbs = @resolver.all_databases

    unique_dbs = dbs.reject { |config, att| 'DATABASE_URL' == config }.map{|config, att| att}.compact

    db_infos = {}
    mutex = Mutex.new
    threads = (0..unique_dbs.size-1).map do |i|
      Thread.new do
        att = unique_dbs[i]
        begin
          info = hpg_info(att, options[:extended])
        rescue
          info = nil
        end
        mutex.synchronize do
          db_infos[att.display_name] = info
        end
      end
    end
    threads.map(&:join)

    @hpg_databases_with_info = db_infos
    return @hpg_databases_with_info
  end

  def hpg_info(attachment, extended=false)
    hpg_client(attachment).get_database(extended)
  end

  def hpg_info_display(item)
    item["values"] = [item["value"]] if item["value"]
    item["values"].map do |value|
      if item["resolve_db_name"]
        @resolver.database_name_from_url(value)
      else
        value
      end
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

  def wait_for(attach)
    ticking do |ticks|
      status = hpg_client(attach).get_wait_status
      error status[:message] if status[:error?]
      break if !status[:waiting?] && ticks.zero?
      redisplay("Waiting for database %s... %s%s" % [
                  attach.display_name,
                  status[:waiting?] ? "#{spinner(ticks)} " : "",
                  status[:message]],
                  !status[:waiting?]) # only display a newline on the last tick
      break unless status[:waiting?]
    end
  end

  def find_uri
    return @uri if defined? @uri

    attachment =  generate_resolver.resolve(shift_argument, "DATABASE_URL")
    if attachment.kind_of? Array
      uri = URI.parse( attachment.last )
    else
      uri = URI.parse( attachment.url )
    end

    @uri = uri
  end

  def version
    return @version if defined? @version
    result = exec_sql("select version();").match(/PostgreSQL (\d+\.\d+\.\d+) on/)
    fail("Unable to determine Postgres version") unless result
    @version = result[1]
  end

  def nine_two?
    return @nine_two if defined? @nine_two
    @nine_two = version.to_f >= 9.2
  end

  def pid_column
    if nine_two?
      'pid'
    else
      'procpid'
    end
  end

  def query_column
    if nine_two?
      'query'
    else
      'current_query'
    end
  end

  def exec_sql(sql)
    uri = find_uri
    exec_sql_on_uri(sql, uri)
  end

  def exec_sql_on_uri(sql,uri)
    begin
      ENV["PGPASSWORD"] = uri.password
      ENV["PGSSLMODE"]  = (uri.host == 'localhost' ?  'prefer' : 'require' )
      user_part = uri.user ? "-U #{uri.user}" : ""
      output = `#{psql_cmd} -c "#{sql}" #{user_part} -h #{uri.host} -p #{uri.port || 5432} #{uri.path[1..-1]}`
      if (! $?.success?) || output.nil? || output.empty?
        raise "psql failed. exit status #{$?.to_i}, output: #{output.inspect}"
      end
      output
    rescue Errno::ENOENT
      output_with_bang "The local psql command could not be located"
      output_with_bang "For help installing psql, see https://devcenter.heroku.com/articles/heroku-postgresql#local-setup"
      abort
    end
  end

  def psql_cmd
    # some people alais psql, so we need to find the real psql
    # but windows doesn't have the command command
    running_on_windows? ? 'psql' : 'command psql'
  end
end
