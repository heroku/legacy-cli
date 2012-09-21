require "heroku/client/heroku_postgresql"
require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"

# manage heroku-postgresql databases
#
class Heroku::Command::Pg < Heroku::Command::Base

  include Heroku::Helpers::HerokuPostgresql

  # pg
  #
  # List databases for an app
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
  # Display database information
  #
  # If DATABASE is not specified, displays all databases
  #
  def info
    db = shift_argument
    validate_arguments!

    if db
      attachment = hpg_resolve(db)
      display_db attachment.display_name, hpg_info(attachment, options[:extended])
    else
      index
    end
  end

  # pg:promote DATABASE
  #
  # Sets DATABASE as your DATABASE_URL
  #
  def promote
    unless db = shift_argument
      error("Usage: heroku pg:promote DATABASE\nMust specify DATABASE to promote.")
    end
    validate_arguments!

    attachment = hpg_resolve(db)

    action "Promoting #{attachment.display_name} to DATABASE_URL" do
      hpg_promote(attachment.url)
    end
  end

  # pg:psql [DATABASE]
  #
  # Open a psql shell to the database
  #
  # defaults to DATABASE_URL databases if no DATABASE is specified
  #
  def psql
    attachment = hpg_resolve(shift_argument, "DATABASE_URL")
    validate_arguments!

    uri = URI.parse( attachment.url )
    begin
      ENV["PGPASSWORD"] = uri.password
      ENV["PGSSLMODE"]  = 'require'
      exec "psql -U #{uri.user} -h #{uri.host} -p #{uri.port || 5432} #{uri.path[1..-1]}"
    rescue Errno::ENOENT
      output_with_bang "The local psql command could not be located"
      output_with_bang "For help installing psql, see http://devcenter.heroku.com/articles/local-postgresql"
      abort
    end
  end

  # pg:reset DATABASE
  #
  # Delete all data in DATABASE
  #
  def reset
    unless db = shift_argument
      error("Usage: heroku pg:reset DATABASE\nMust specify DATABASE to reset.")
    end
    validate_arguments!

    attachment = hpg_resolve(db) unless db == "SHARED_DATABASE"
    return unless confirm_command

    if db == "SHARED_DATABASE"
      action("Resetting SHARED_DATABASE") { heroku.database_reset(app) }
    else
      action("Resetting #{attachment.display_name}") do
        hpg_client(attachment).reset
      end
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

    replica = hpg_resolve(db)
    replica_info = hpg_info(replica)

    unless replica_info[:following]
      error("#{replica.display_name} is not following another database.")
    end
    origin_url = replica_info[:following]
    origin_name = database_name_from_url(origin_url)

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
      wait_for hpg_resolve(db)
    else
      hpg_databases.values.each do |attach|
        wait_for(attach)
      end
    end
  end

  # pg:credentials DATABASE
  #
  # Display the DATABASE credentials.
  #
  #   --reset  # Reset credentials on the specified database.
  #
  def credentials
    unless db = shift_argument
      error("Usage: heroku pg:credentials DATABASE\nMust specify DATABASE to display credentials.")
    end
    validate_arguments!

    attachment = hpg_resolve(db)

    if options[:reset]
      action "Resetting credentials for #{attachment.display_name}" do
        hpg_client(attachment).rotate_credentials
      end
      if attachment.primary_attachment?
        forget_config!
        attachment = hpg_resolve(db)
        action "Promoting #{attachment.display_name}" do
          hpg_promote(attachment.url)
        end
      end
    else
      uri = URI.parse( attachment.url )
      display "Connection info string:"
      display "   \"dbname=#{uri.path[1..-1]} host=#{uri.host} port=#{uri.port || 5432} user=#{uri.user} password=#{uri.password} sslmode=require\""
    end
  end

private

  def database_name_from_url(url)
    vars = app_config_vars.reject {|key,value| key == 'DATABASE_URL'}
    if var = vars.invert[url]
      var.gsub(/_URL$/, '')
    else
      uri = URI.parse(url)
      "Database on #{uri.host}:#{uri.port || 5432}#{uri.path}"
    end
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

    @hpg_databases_with_info = Hash[ hpg_databases.map { |config, att| [att.display_name, hpg_info(att, options[:extended])] } ]

    return @hpg_databases_with_info
  end

  def hpg_info(attachment, extended=false)
    if attachment.resource_name == "SHARED_DATABASE"
      data = api.get_app(app).body
      {:info => [{
        'name'    => 'Data Size',
        'values'  => [format_bytes(data['database_size'])]
      }]}
    else
      hpg_client(attachment).get_database(extended)
    end
  end

  def hpg_info_display(item)
    item["values"] = [item["value"]] if item["value"]
    item["values"].map do |value|
      if item["resolve_db_name"]
        database_name_from_url(value)
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

end
