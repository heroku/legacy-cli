require "heroku/helpers"

module Heroku::Helpers::HerokuPostgresql

  extend self
  extend Heroku::Helpers

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
      elsif name == 'SHARED_DATABASE_URL'
        hash.update('SHARED_DATABASE' => url)
      end
      hash
    end
  end

  def forget_config!
    @hpg_databases   = nil
    @app_config_vars = nil
  end

  def hpg_resolve(name, default=nil)
    uri = URI.parse(name) rescue nil
    if uri && uri.scheme
      [nil, name]
    else
      if app_config_vars["DATABASE_URL"]
        hpg_databases["DATABASE"] = app_config_vars["DATABASE_URL"]
      end
      if hpg_databases.empty?
        error("Your app has no databases.")
      end

      name = name.to_s.upcase.gsub(/_URL$/, "")

      if hpg_databases[name]
        [hpg_pretty_name(name), hpg_databases[name]]
      elsif (config_var = "HEROKU_POSTGRESQL_#{name}") && hpg_databases[config_var]
        [hpg_pretty_name(config_var), hpg_databases[config_var]]
      elsif default && name.empty? && app_config_vars[default]
        [hpg_pretty_name(default), app_config_vars[default]]
      elsif name.empty?
        error("Unknown database. Valid options are: #{hpg_databases.keys.sort.join(", ")}")
      else
        error("Unknown database: #{name}. Valid options are: #{hpg_databases.keys.sort.join(", ")}")
      end
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

  private

  def hpg_pretty_name(name)
    if ['DATABASE', 'DATABASE_URL'].include?(name)
      if key = app_config_vars.keys.detect do |key|
          if key == 'DATABASE_URL'
            next
          else
            app_config_vars[key] == app_config_vars['DATABASE_URL']
          end
        end
        "#{key.gsub(/_URL$/, '')} (DATABASE_URL)"
      else
        name.gsub(/_URL$/, '')
      end
    elsif hpg_databases[name] == hpg_databases['DATABASE']
      "#{name} (DATABASE_URL)"
    else
      name
    end
  end

  def hpg_promote(url)
    api.put_config_vars(app, "DATABASE_URL" => url)
  end

end
