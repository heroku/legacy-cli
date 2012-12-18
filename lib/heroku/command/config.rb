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
      vars.each {|key, value| vars[key] = value.to_s}
      if options[:shell]
        vars.keys.sort.each do |key|
          display(%{#{key}=#{vars[key]}})
        end
      else
        styled_header("#{app} Config Vars")
        styled_hash(vars)
      end
    end
  end

  # config:set KEY1=VALUE1 [KEY2=VALUE2 ...]
  #
  # set one or more config vars
  #
  #Example:
  #
  # $ heroku config:set A=one
  # Setting config vars and restarting example... done, v123
  # A: one
  #
  # $ heroku config:set A=one B=two
  # Setting config vars and restarting example... done, v123
  # A: one
  # B: two
  #
  def set
    unless args.size > 0 and args.all? { |a| a.include?('=') }
      error("Usage: heroku config:set KEY1=VALUE1 [KEY2=VALUE2 ...]\nMust specify KEY and VALUE to set.")
    end

    vars = args.inject({}) do |vars, arg|
      key, value = arg.split('=', 2)
      vars[key] = value
      vars
    end

    action("Setting config vars and restarting #{app}") do
      api.put_config_vars(app, vars)

      @status = begin
        if release = api.get_release(app, 'current').body
          release['name']
        end
      rescue Heroku::API::Errors::RequestFailed => e
      end
    end

    vars.each {|key, value| vars[key] = value.to_s}
    styled_hash(vars)
  end

  alias_command "config:add", "config:set"

  # config:get KEY
  #
  # display a config value for an app
  #
  #Examples:
  #
  # $ heroku config:get A
  # one
  #
  def get
    unless key = shift_argument
      error("Usage: heroku config:get KEY\nMust specify KEY.")
    end
    validate_arguments!

    vars = api.get_config_vars(app).body
    key, value = vars.detect {|k,v| k == key}
    display(value.to_s)
  end

  # config:unset KEY1 [KEY2 ...]
  #
  # unset one or more config vars
  #
  # $ heroku config:unset A
  # Unsetting A and restarting example... done, v123
  #
  # $ heroku config:unset A B
  # Unsetting A and restarting example... done, v123
  # Unsetting B and restarting example... done, v124
  #
  def unset
    if args.empty?
      error("Usage: heroku config:unset KEY1 [KEY2 ...]\nMust specify KEY to unset.")
    end

    args.each do |key|
      action("Unsetting #{key} and restarting #{app}") do
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

  alias_command "config:remove", "config:unset"

end
