require "heroku/command/base"

# manage app config vars
#
class Heroku::Command::Config < Heroku::Command::Base

  # config
  #
  # display the config vars for an app
  #
  # -s, --shell  # output config vars in shell format
  #
  #Examples:
  #
  # $ heroku config
  # A: one
  # B: two
  #
  # $ heroku config --shell
  # A=one
  # B=two
  #
  def index
    validate_arguments!

    vars = api.get_config_vars(app).body
    if vars.empty?
      display("#{app} has no config vars.")
    else
      if options[:shell]
        vars.keys.sort.each do |key|
          display("#{key}=#{vars[key]}")
        end
      else
        styled_header("Config Vars for #{app}")
        styled_hash(vars)
      end
    end
  end

  # config:add KEY1=VALUE1 ...
  #
  # add one or more config vars
  #
  #Example:
  #
  # $ heroku config:add A=one
  # Adding config vars and restarting myapp... done, v123
  # A: one
  #
  # $ heroku config:add A=one B=two
  # Adding config vars and restarting myapp... done, v123
  # A: one
  # B: two
  #
  def add
    unless args.size > 0 and args.all? { |a| a.include?('=') }
      error("Usage: heroku config:add <key>=<value> [<key2>=<value2> ...]")
    end

    vars = args.inject({}) do |vars, arg|
      key, value = arg.split('=', 2)
      vars[key] = value
      vars
    end

    action("Adding config vars and restarting #{app}") do
      api.put_config_vars(app, vars)

      @status = begin
        if release = api.get_release(app, 'current').body
          release['name']
        end
      rescue Heroku::API::Errors::RequestFailed => e
      end
    end

    styled_hash(vars)
  end

  alias_command "config:set", "config:add"

  # config:remove KEY1 [KEY2 ...]
  #
  # remove a config var
  #
  # $ heroku config:add A=one
  # Removing A and restarting myapp... done, v123
  #
  # $ heroku config:add A B
  # Adding A and restarting myapp... done, v123
  # Adding B and restarting myapp... done, v124
  #
  def remove
    if args.empty?
      error("Usage: heroku config:remove KEY1 [KEY2 ...]")
    end

    args.each do |key|
      action("Removing #{key} and restarting #{app}") do
        api.delete_config_var(app, key)

        @status = begin
          if release = api.get_release(app, 'current').body
            release['name']
          end
        rescue Heroku::API::Errors::RequestFailed => e
        end
      end
    end
  end

end
