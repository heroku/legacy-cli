module Heroku::Command
  class Config < BaseWithApp
    def index
      long = args.delete('--long')
      vars = heroku.config_vars(app)
      display_vars(vars, :long => long)
    end

    def add
      unless args.size > 0 and args.all? { |a| a.include?('=') }
        raise CommandFailed, "Usage: heroku config:add <key>=<value> [<key2>=<value2> ...]"
      end

      vars = args.inject({}) do |vars, arg|
        key, value = arg.split('=', 2)
        vars[key] = value
        vars
      end

      display "Adding config vars:"
      display_vars(vars, :indent => 2)

      display "Restarting app...", false
      heroku.add_config_vars(app, vars)
      display "done."
    end

    def remove
      display "Removing #{args.first} and restarting app...", false
      heroku.remove_config_var(app, args.first)
      display "done."
    end
    alias :rm :remove

    def clear
      display "Clearing all config vars and restarting app...", false
      heroku.clear_config_vars(app)
      display "done."
    end

    protected
      def display_vars(vars, options={})
        max_length = vars.map { |v| v[0].size }.max
        vars.keys.sort.each do |key|
          spaces = ' ' * (max_length - key.size)
          display "#{' ' * (options[:indent] || 0)}#{key}#{spaces} => #{format(vars[key], options)}"
        end
      end

      def format(value, options)
        return value if options[:long] || value.size < 36
        value[0, 16] + '...' + value[-16, 16]
      end
  end
end
