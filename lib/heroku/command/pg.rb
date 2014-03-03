require "heroku/client/heroku_postgresql"
require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"
require "heroku/helpers/pg_dump_restore"

# manage heroku-postgresql databases
#
class Heroku::Command::Pg < Heroku::Command::Base

  include Heroku::Helpers::HerokuPostgresql

  # pg
  #
  # list databases for an app
  #
  def index
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

    if db
      @resolver = generate_resolver
      attachment = @resolver.resolve(db)
      display_db attachment.display_name, hpg_info(attachment, options[:extended])
    else
      index
    end
  end

  # pg:promote DATABASE
  #
  # sets DATABASE as your DATABASE_URL
  #
  def promote
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
    attachment = generate_resolver.resolve(shift_argument, "DATABASE_URL")
    validate_arguments!

    uri = URI.parse( attachment.url )
    begin
      ENV["PGPASSWORD"] = uri.password
      ENV["PGSSLMODE"]  = 'require'
      if command = options[:command]
        command = "-c '#{command}'"
      end

      shorthand = "#{attachment.app}::#{attachment.name.sub(/^HEROKU_POSTGRESQL_/,'').gsub(/\W+/, '-')}"
      prompt_expr = "#{shorthand}%R%# "
      prompt_flags = %Q(--set "PROMPT1=#{prompt_expr}" --set "PROMPT2=#{prompt_expr}")
      puts "---> Connecting to #{attachment.display_name}"
      exec "psql -U #{uri.user} -h #{uri.host} -p #{uri.port || 5432} #{prompt_flags} #{command} #{uri.path[1..-1]}"
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
    sql = %Q(
      SELECT pg_terminate_backend(#{pid_column})
      FROM pg_stat_activity
      WHERE #{pid_column} <> pg_backend_pid()
      AND #{query_column} <> '<insufficient privilege>'
    )

    puts exec_sql(sql)
  end


  # pg:push <LOCAL_SOURCE_DATABASE> <REMOTE_TARGET_DATABASE>
  #
  # push from LOCAL_SOURCE_DATABASE to REMOTE_TARGET_DATABASE
  # REMOTE_TARGET_DATABASE must be empty.
  def push
    local, remote = shift_argument, shift_argument
    unless [remote, local].all?
      Heroku::Command.run(current_command, ['--help'])
      exit(1)
    end
    if local =~ %r(://)
      error "LOCAL_SOURCE_DATABASE is not a valid database name"
    end

    remote_uri = generate_resolver.resolve(remote).url
    local_uri = "postgres:///#{local}"

    pgdr = PgDumpRestore.new(
      local_uri,
      remote_uri,
      self)

    pgdr.execute
  end

  # pg:pull <REMOTE_SOURCE_DATABASE> <LOCAL_TARGET_DATABASE>
  #
  # pull from REMOTE_SOURCE_DATABASE to LOCAL_TARGET_DATABASE
  # LOCAL_TARGET_DATABASE must not already exist.
  def pull
    remote, local = shift_argument, shift_argument
    unless [remote, local].all?
      Heroku::Command.run(current_command, ['--help'])
      exit(1)
    end
    if local =~ %r(://)
      error "LOCAL_TARGET_DATABASE is not a valid database name"
    end

    remote_uri = generate_resolver.resolve(remote).url
    local_uri = "postgres:///#{local}"

    pgdr = PgDumpRestore.new(
      remote_uri,
      local_uri,
      self)

    pgdr.execute
  end

private

  def generate_resolver
    app_name = app rescue nil # will raise if no app, but calling app reads in arguments
    Resolver.new(app_name, api)
  end

  def display_db(name, db)
    styled_header(name)
    styled_hash(db[:info].inject({}) do |hash, item|
      hash.update(item["name"] => hpg_info_display(item))
    end, db[:info].map {|item| item['name']})

    display
  end

  def hpg_client(attachment)
    Heroku::Client::HerokuPostgresql.new(attachment)
  end

  def hpg_databases_with_info
    return @hpg_databases_with_info if @hpg_databases_with_info

    @resolver = generate_resolver
    dbs = @resolver.all_databases

    db_infos = dbs.reject { |config, att|
                 'DATABASE_URL' == config
               }.map { |config, att|
                 [att.display_name, hpg_info(att, options[:extended])]
               }

    @hpg_databases_with_info = Hash[db_infos]
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
    @version = exec_sql("select version();").match(/PostgreSQL (\d+\.\d+\.\d+) on/)[1]
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
      sslmode = (uri.host == 'localhost' ?  'prefer' : 'require' )
      user_part = uri.user ? "-U #{uri.user}" : ""
      `env PGPASSWORD=#{uri.password} PGSSLMODE=#{sslmode} psql -c "#{sql}" #{user_part} -h #{uri.host} -p #{uri.port || 5432} #{uri.path[1..-1]}`
    rescue Errno::ENOENT
      output_with_bang "The local psql command could not be located"
      output_with_bang "For help installing psql, see https://devcenter.heroku.com/articles/heroku-postgresql#local-setup"
      abort
    end
  end

end
