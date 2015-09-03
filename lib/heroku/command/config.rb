require "heroku/command/base"
require "shellwords"


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

    vars = if options[:shell]
             api.get_config_vars(app).body
           else
             api.request(
               :expects  => 200,
               :method   => :get,
               :path     => "/apps/#{app}/config_vars",
               :query    => { "symbolic" => true }
             ).body
           end

    if vars.empty?
      display("#{app} has no config vars.")
    else
      vars.each {|key, value| vars[key] = value.to_s}
      if options[:shell]
        vars.keys.sort.each do |key|
          out = $stdout.tty? ? Shellwords.shellescape(vars[key]) : vars[key]
          display(%{#{key}=#{out}})
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
    requires_preauth
    unless args.size > 0 and args.all? { |a| a.include?('=') }
      error("Usage: heroku config:set KEY1=VALUE1 [KEY2=VALUE2 ...]\nMust specify KEY and VALUE to set.")
    end

    vars = args.inject({}) do |v, arg|
      key, value = arg.split('=', 2)
      v[key] = value
      v
    end

    action("Setting config vars and restarting #{app}") do
      api.put_config_vars(app, vars)

      @status = begin
        if release = api.get_release(app, 'current').body
          release['name']
        end
      rescue Heroku::API::Errors::RequestFailed
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
  # -s, --shell  # output config var in shell format
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
    if options[:shell] && value
      out = $stdout.tty? ? Shellwords.shellescape(value) : value
      display("#{key}=#{out}")
    else
      display(value.to_s)
    end
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
    requires_preauth
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
        rescue Heroku::API::Errors::RequestFailed
        end
      end
    end
  end

  alias_command "config:remove", "config:unset"

  # config:copy APP2
  #
  # copy config variables from one application to another
  #
  # $ heroku config:copy APP2 --APP1
  # App1 config vars copied to APP2
  #
  def copy
    requires_preauth

    if args.empty?
      error("Usage: heroku config:copy APP\nMust specify target application.")
    end

    vars = api.get_config_vars(app).body
    api.put_config_vars(args.first, vars)
    copied_vars = api.get_config_vars(args.first).body

    display("#{app} config vars copied to #{args.first}")
  end

end
