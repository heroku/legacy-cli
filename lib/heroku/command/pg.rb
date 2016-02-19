require "thread"

require "heroku/client/heroku_postgresql"
require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"
require "heroku/helpers/pg_dump_restore"
require "heroku/helpers/addons/resolve"
require "heroku/helpers/addons/api"
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
  include Heroku::Helpers::Addons::Resolve
  include Heroku::Helpers::Addons::API

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
  # display database information
  #
  #   -x, --extended  # Show extended information
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

    addon = resolve_addon!(db)

    if addon['addon_service']['name'] != 'heroku-postgresql'
      name = db == addon['name'] ? db : "#{db} (#{addon['name']})"
      error("Cannot promote #{name}. It needs to be heroku-postgresql, not #{addon['addon_service']['name']}.")
    end

    promoted_name = 'DATABASE'

    action "Ensuring an alternate alias for existing #{promoted_name}" do
      backup = find_or_create_non_database_attachment(app)

      if backup
        @status = backup['name']
      else
        @status = "not needed"
      end

    end

    action "Promoting #{addon['name']} to #{promoted_name}_URL on #{app}" do
      request(
        :body     => json_encode({
          "app"     => {"name" => app},
          "addon"   => {"name" => addon['name']},
          "confirm" => app,
          "name"    => promoted_name
        }),
        :expects  => 201,
        :method   => :post,
        :path     => "/addon-attachments"
      )
    end
  end

  # pg:psql [DATABASE]
  #
  # open a psql shell to the database
  #
  #  -c, --command COMMAND      # optional SQL command to run
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
      ENV["PGAPPNAME"]  = "#{pgappname} interactive"
      if command = options[:command]
        command = %Q(-c "#{command}")
      end

      shorthand = "#{attachment.app}::#{attachment.name.sub(/^HEROKU_POSTGRESQL_/,'').gsub(/\W+/, '-')}"
      set_commands = Hooks.set_commands(shorthand)
      prompt_expr = "#{shorthand}%R%# "
      prompt_flags = %Q(--set "PROMPT1=#{prompt_expr}" --set "PROMPT2=#{prompt_expr}")
      puts "---> Connecting to #{attachment.display_name}"
      attachment.maybe_tunnel do |uri|
        command = "psql -U #{uri.user} -h #{uri.host} -p #{uri.port || 5432} #{set_commands} #{prompt_flags} #{command} #{uri.path[1..-1]}"
        if attachment.uses_bastion?
          spawn(command)
          Process.wait
          exit($?.exitstatus)
        else
          exec(command)
        end
      end
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
  # --wait-interval SECONDS      # how frequently to poll (to avoid rate-limiting)
  #
  def wait
    requires_preauth
    db = shift_argument
    validate_arguments!
    interval = options[:wait_interval].to_i
    interval = 1 if interval < 1

    if db
      wait_for(generate_resolver.resolve(db), interval)
    else
      generate_resolver.all_databases.values.each do |attach|
        wait_for(attach, interval)
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
  #   -v,--verbose # also show idle connections
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
      # Apply idle-backend filter appropriate to versions and options.
      case
      when options[:verbose]
        ''
      when nine_two?
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

    cmd = force? ? 'pg_terminate_backend' : 'pg_cancel_backend'
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

    target_attachment = resolve_heroku_attachment(remote)
    source_uri = parse_db_url(local)

    target_attachment.maybe_tunnel do |uri|
      pgdr = PgDumpRestore.new(
        source_uri,
        uri.to_s,
        self)
      pgdr.execute
    end
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

    source_attachment = resolve_heroku_attachment(remote)
    target_uri = parse_db_url(local)

    source_attachment.maybe_tunnel do |uri|
      pgdr = PgDumpRestore.new(
        uri.to_s,
        target_uri,
        self)
      pgdr.execute
    end
  end


  # pg:maintenance <info|run|window> <DATABASE>
  #
  # manage maintenance for <DATABASE>
  # info               # show current maintenance information
  # run                # start maintenance
  #   -f, --force      #   run pg:maintenance without entering application maintenance mode
  # window="<window>"  # set weekly UTC maintenance window for DATABASE
  #                     # eg: `heroku pg:maintenance window="Sunday 14:30"`
  def maintenance
    requires_preauth
    mode_with_argument = shift_argument || ''
    mode, mode_argument = mode_with_argument.split('=')

    db   = shift_argument
    no_maintenance = force?
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
  # unfollow a database and upgrade it to the latest stable PostgreSQL version
  #
  # To upgrade to another PostgreSQL version, use pg:copy instead
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

  # pg:links <create|destroy>
  #
  # create links between data stores.  Without a subcommand, it lists all
  # databases and information on the link.
  #
  # create <REMOTE> <LOCAL>   # Create a data link
  #   --as <LINK>              # override the default link name
  # destroy <LOCAL> <LINK>    # Destroy a data link between a local and remote database
  #
  def links
    requires_preauth
    mode = shift_argument || 'list'

    if !(%w(list create destroy).include?(mode))
      Heroku::Command.run(current_command, ["--help"])
      exit(1)
    end

    case mode
    when 'list'
      db = shift_argument
      resolver = generate_resolver

      if db
        dbs = [resolver.resolve(db, "DATABASE_URL")]
      else
        dbs = resolver.all_databases.values
      end

      dbs_by_addons = dbs.group_by(&:resource_name)

      error("No database attached to this app.") if dbs.compact.empty?

      dbs_by_addons.each_with_index do |(resource, attachments), index|
        response = hpg_client(attachments.first).link_list
        display "\n" if index.nonzero?

        styled_header("#{attachments.map(&:config_var).join(", ")} (#{resource})")

        next display response[:message] if response.kind_of?(Hash)
        next display "No data sources are linked into this database." if response.empty?

        response.each do |link|
          display "==== #{link[:name]}"

          link[:created] = time_format(link[:created_at])
          link[:remote] = "#{link[:remote]['attachment_name']} (#{link[:remote]['name']})"
          link.reject! { |k,_| [:id, :created_at, :name].include?(k) }
          styled_hash(Hash[link.map {|k, v| [humanize(k), v] }])
        end
      end
    when 'create'
      remote = shift_argument
      local = shift_argument

      error("Usage links <LOCAL> <REMOTE>") unless [local, remote].all?

      local_attachment = generate_resolver.resolve(local, "DATABASE_URL")
      remote_attachment = resolve_service(remote)

      output_with_bang("No source database specified.") unless local_attachment
      output_with_bang("No remote database specified.") unless remote_attachment

      response = hpg_client(local_attachment).link_set(remote_attachment.name, options[:as])

      if response.has_key?(:message)
        output_with_bang(response[:message])
      else
        display("New link '#{response[:name]}' successfully created.")
      end
    when 'destroy'
      local = shift_argument
      link = shift_argument

      error("No local database specified.") unless local
      error("No link name specified.") unless link

      local_attachment = generate_resolver.resolve(local, "DATABASE_URL")

      message = [
        "WARNING: Destructive Action",
        "This command will affect the database: #{local}",
        "This will delete #{link} along with the tables and views created within it.",
        "This may have adverse effects for software written against the #{link} schema."
      ].join("\n")

      if confirm_command(app, message)
        action("Deleting link #{link} in #{local}") do
          hpg_client(local_attachment).link_delete(link)
        end
      end
    end
  end

  private

  def humanize(key)
    key.to_s.gsub(/_/, ' ').split(" ").map(&:capitalize).join(" ")
  end

  def resolve_service(name)
    addon = resolve_addon!(name)

    error("Remote database is invalid.") unless addon['addon_service']['name'] =~ /heroku-(redis|postgresql)/

    MaybeAttachment.new(addon['name'], nil, addon)
  rescue Heroku::API::Errors::NotFound
    error("Remote database could not be found.")
  end

  def get_config_var(name)
    res = api.get_config_vars(app)
    res.data[:body][name]
  end

  def resolve_heroku_attachment(remote)
    generate_resolver.resolve(remote)
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

  def in_maintenance?(app)
    api.get_app_maintenance(app).body['maintenance']
  end

  def time_format(time)
    Time.parse(time).getutc.strftime("%Y-%m-%d %H:%M %Z")
  end

  def hpg_client(attachment)
    Heroku::Client::HerokuPostgresql.new(attachment)
  end

  def hpg_databases_with_info
    return @hpg_databases_with_info if @hpg_databases_with_info

    @resolver = generate_resolver
    attachments = @resolver.all_databases

    attachments_by_db = attachments.values.group_by(&:resource_name)

    db_infos = {}
    mutex = Mutex.new
    threads = attachments_by_db.map do |resource, attachments|
      Thread.new do
        begin
          info = hpg_info(attachments.first, options[:extended])
        rescue
          info = nil
        end

        # Make headers as per heroku/heroku#1605
        names = attachments.map(&:config_var)
        names << 'DATABASE_URL' if attachments.any? { |att| att.primary_attachment? }
        name = names.
          uniq.
          sort_by { |n| n=='DATABASE_URL' ? '{' : n }. # Weight DATABASE_URL last
          join(', ')

        mutex.synchronize do
          db_infos[name] = info
        end
      end
    end
    threads.map(&:join)

    @hpg_databases_with_info = db_infos
    return @hpg_databases_with_info
  end

  def hpg_info(attachment, extended=false)
    info = hpg_client(attachment).get_database(extended)

    # TODO: Make this the section title and list the current `name` as an
    # "Attachments" item here:
    info.merge(:info => info[:info] + [{"name" => "Add-on", "values" => [attachment.resource_name]}])
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

  def ticking(interval)
    ticks = 0
    loop do
      yield(ticks)
      ticks +=1
      sleep interval
    end
  end

  def wait_for(attach, interval)
    ticking(interval) do |ticks|
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
    @attachment ||= generate_resolver.resolve(shift_argument, "DATABASE_URL")
    @attachment.maybe_tunnel do |uri|
      exec_sql_on_uri(sql, uri)
    end
  end

  def exec_sql_on_uri(sql,uri)
    begin
      ENV["PGPASSWORD"] = uri.password
      ENV["PGSSLMODE"]  = (uri.host == 'localhost' ?  'prefer' : 'require' )
      ENV["PGAPPNAME"]  = "#{pgappname} non-interactive"
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

  def pgappname
    if running_on_windows?
      'psql (windows)'
    else
      "psql #{`whoami`.chomp.gsub(/\W/,'')}"
    end
  end

  def psql_cmd
    # some people alais psql, so we need to find the real psql
    # but windows doesn't have the command command
    running_on_windows? ? 'psql' : 'command psql'
  end

  # Finds or creates a non-DATABASE attachment for the DB currently
  # attached as DATABASE.
  #
  # If current DATABASE is attached by other names, return one of them.
  # If current DATABASE is only attachment, create a new one and return it.
  # If no current DATABASE, return nil.
  def find_or_create_non_database_attachment(app)
    attachments = get_attachments(:app => app)

    current_attachment = attachments.detect { |att| att['name'] == 'DATABASE' }
    current_addon      = current_attachment && current_attachment['addon']

    if current_addon
      existing = attachments.
        select { |att| att['addon']['id'] == current_addon['id'] }.
        detect { |att| att['name'] != 'DATABASE' }

      return existing if existing

      # The current add-on occupying the DATABASE attachment has no
      # other attachments. In order to promote this database without
      # error, we can create a secondary attachment, just-in-time.
      request(
        # Note: no attachment name provided; let the API choose one
        :body     => json_encode({
          "app"     => {"name" => app},
          "addon"   => {"name" => current_addon['name']},
          "confirm" => app
        }),
        :expects  => 201,
        :method   => :post,
        :path     => "/addon-attachments"
      )
    end
  end

  def force?
    options[:force] || ENV['HEROKU_FORCE'] == '1'
  end
end
