require "heroku/helpers"

module Heroku::Helpers::HerokuPostgresql

  extend self

  def app_config_vars
    @app_config_vars ||= api.get_config_vars(app).body
  end

  def hpg_addon_name
    ENV['HEROKU_POSTGRESQL_ADDON_NAME'] || 'heroku-postgresql'
  end

  def hpg_addon_prefix
    ENV["HEROKU_POSTGRESQL_ADDON_PREFIX"] || "HEROKU_POSTGRESQL"
  end

  def hpg_databases
    @hpg_databases ||= app_config_vars.inject({}) do |hash, (name, url)|
      if name =~ /^(#{hpg_addon_prefix}\w+)_URL$/
        hash.update($1 => url)
      end
      hash
    end
  end

  def hpg_resolve(name, default=nil)
    dbs = hpg_databases
    if app_config_vars["DATABASE_URL"]
      dbs["DATABASE"] = app_config_vars["DATABASE_URL"]
    end
    if dbs.empty?
      error("Your app has no databases.")
    end

    name = name.to_s.upcase.gsub(/_URL$/, "")

    if dbs[name]
      [name, dbs[name]]
    elsif dbs["HEROKU_POSTGRESQL_#{name}"]
      ["HEROKU_POSTGRESQL_#{name}", dbs["HEROKU_POSTGRESQL_#{name}"]]
    elsif (default && name.empty? && app_config_vars[default])
      [default, app_config_vars[default]]
    elsif name.empty?
      error("Unknown database. Valid options are: #{dbs.keys.sort.join(", ")}")
    else
      error("Unknown database: #{name}. Valid options are: #{dbs.keys.sort.join(", ")}")
    end
  end

  def hpg_translate_fork_and_follow(addon, config)
    if addon =~ /^#{hpg_addon_name}/
      %w[fork follow].each do |opt|
        if val = config[opt]
          unless val.is_a?(String)
            error("--#{opt} requires a database argument")
          end
          name, url = hpg_resolve(val)
          config[opt] = url
        end
      end
    end
  end

end
