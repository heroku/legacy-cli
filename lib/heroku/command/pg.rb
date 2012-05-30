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

    hpg_databases_with_info.keys.sort.each do |name|
      display_db name, hpg_databases_with_info[name]
    end
  end

  # pg:info [DATABASE]
  #
  # Display database information
  #
  # If DATABASE is not specified, displays all databases
  #
  def info
    db = shift_argument
    validate_arguments!

    if db
      name, url = hpg_resolve(db)
      display_db name, hpg_info(url)
    else
      hpg_databases_with_info.keys.sort.each do |name|
        display_db name, hpg_databases_with_info[name]
      end
    end
  end

  # pg:promote DATABASE
  #
  # Sets DATABASE as your DATABASE_URL
  #
  def promote
    unless db = shift_argument
      error("Usage: heroku pg:promote DATABASE")
    end
    validate_arguments!

    if URI.parse(db).scheme
      url = db
      display_name = "custom URL"
    else
      display_name, url = hpg_resolve(db)
    end

    action "Promoting #{display_name} to DATABASE_URL" do
      api.put_config_vars(app, "DATABASE_URL" => url)
    end
  end

  # pg:psql [DATABASE]
  #
  # Open a psql shell to the database
  #
  # defaults to DATABASE_URL databases if no DATABASE is specified
  #
  def psql
    name, url = hpg_resolve(shift_argument, "DATABASE_URL")
    validate_arguments!

    uri = URI.parse(url)
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
      error("Usage: pg:reset DATABASE")
    end
    validate_arguments!

    name, url = hpg_resolve(db)
    return unless confirm_command

    action("Resetting #{name}") do
      hpg_client(url).reset
    end
  end

  # pg:unfollow REPLICA
  #
  # stop a replica from following and make it a read/write database
  #
  def unfollow
    unless db = shift_argument
      error("Usage: heroku pg:unfollow REPLICA")
    end
    validate_arguments!

    replica_name, replica_url = hpg_resolve(db)
    replica = hpg_info(replica_url)

    unless replica[:following]
      error("#{replica_name} is not following another database.")
    end
    origin_url = replica[:following]
    origin_name = database_name_from_url(origin_url)

    output_with_bang "#{replica_name} will become writable and no longer"
    output_with_bang "follow #{origin_name}. This cannot be undone."
    return unless confirm_command

    action "Unfollowing #{db}" do
      hpg_client(origin_url).unfollow
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
      wait_for hpg_info(hpg_resolve(db).last)
    else
      hpg_databases_with_info.keys.sort.each do |name|
        wait_for hpg_databases_with_info[name]
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
      error("Usage: heroku pg:credentials DATABASE")
    end
    validate_arguments!

    name, url = hpg_resolve(db)

    if options[:reset]
      action "Resetting credentials for #{name}" do
        hpg_client(url).rotate_credentials
      end
    else
      uri = URI.parse(url)
      display "Connection info string:"
      display "   \"dbname=#{uri.path[1..-1]} host=#{uri.host} port=#{uri.port || 5432} user=#{uri.user} password=#{uri.password} sslmode=require\""
    end
  end

private

  def database_name_from_url(url)
    vars = app_config_vars
    vars.delete "DATABASE_URL"
    (vars.invert[url] || url).gsub(/_URL$/, "")
  end

  def display_db(name, db)
    pretty_name = name
    if db[:url] == app_config_vars["DATABASE_URL"] && !pretty_name.include?(' (DATABASE_URL)')
      pretty_name += " (DATABASE_URL)"
    end

    styled_header(pretty_name)
    styled_hash(db[:info].inject({}) do |hash, item|
      hash.update(item["name"] => hpg_info_display(item))
    end)

    display
  end

  def hpg_client(url)
    Heroku::Client::HerokuPostgresql.new(url)
  end

  def hpg_databases_with_info
    @hpg_databases_with_info ||= hpg_databases.inject({}) do |hash, (name, url)|
      hash.update(name => hpg_info(url))
    end
  end

  def hpg_info(url)
    info = hpg_client(url).get_database
    info[:url] = url
    info
  end

  def hpg_info_display(item)
    item["values"] = [item["value"]] if item["value"]
    if item["name"] == "Conn Info"
      "\n  #{item["values"].join("\n  ")}\n\n"
    else
      item["values"].map do |value|
        if item["resolve_db_name"]
          database_name_from_url(value)
        else
          value
        end
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

  def wait_for(db)
    ticking do |ticks|
      status = hpg_client(db[:url]).get_wait_status
      error status[:message] if status[:error?]
      break if !status[:waiting?] && ticks.zero?
      redisplay("Waiting for database %s... %s%s" % [
                  db[:pretty_name],
                  status[:waiting?] ? "#{spinner(ticks)} " : "",
                  status[:message]],
                  !status[:waiting?]) # only display a newline on the last tick
      break unless status[:waiting?]
    end
  end

end
