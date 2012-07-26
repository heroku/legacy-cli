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

    name, url = hpg_resolve(db)
    name ||= 'Custom URL'

    action "Promoting #{name} to DATABASE_URL" do
      hpg_promote(url)
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
      error("Usage: pg:reset DATABASE\nMust specify DATABASE to reset.")
    end
    validate_arguments!

    name, url = hpg_resolve(db)
    return unless confirm_command

    action("Resetting #{name}") do
      if name =~ /^SHARED_DATABASE/i
        heroku.database_reset(app)
      else
        hpg_client(url).reset
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
      hpg_client(replica_url).unfollow
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
        unless name =~ /^SHARED_DATABASE/i
          wait_for(hpg_databases_with_info[name])
        end
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

    name, url = hpg_resolve(db)

    url_is_database_url = (url == app_config_vars["DATABASE_URL"])

    if options[:reset]
      action "Resetting credentials for #{name}" do
        hpg_client(url).rotate_credentials
      end
      if url_is_database_url
        forget_config!
        name, new_url = hpg_resolve(db)
        action "Promoting #{name}" do
          hpg_promote(new_url)
        end
      end
    else
      uri = URI.parse(url)
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
    pretty_name = name
    if !pretty_name.include?(' (DATABASE_URL)') && app_config_vars["#{name}_URL"] == app_config_vars["DATABASE_URL"]
      pretty_name += " (DATABASE_URL)"
    end

    styled_header(pretty_name)
    styled_hash(db[:info].inject({}) do |hash, item|
      hash.update(item["name"] => hpg_info_display(item))
    end, db[:info].map {|item| item['name']})

    display
  end

  def hpg_client(url)
    Heroku::Client::HerokuPostgresql.new(url)
  end

  def hpg_databases_with_info
    @hpg_databases_with_info ||= hpg_databases.inject({}) do |hash, (name, url)|
      if name =~ /^SHARED_DATABASE/i
        data = api.get_app(app).body
        hash.update(name => {
          :info => [{
            'name'    => 'Data Size',
            'values'  => [format_bytes(data['database_size'])]
          }],
          :url        => url
        })
      else
        hash.update(name => hpg_info(url))
      end
    end
  end

  def hpg_info(url)
    info = hpg_client(url).get_database
    info[:url] = url
    info
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
