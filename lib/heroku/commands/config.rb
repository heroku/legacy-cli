module Heroku::Command
	class Config < BaseWithApp
		def index
			long = args.delete('--long')
			vars = heroku.config_vars(app)
			display_vars(vars, long)
		end

		def add
			unless args.all? { |a| a.include?('=') }
				raise CommandFailed, "Usage: heroku config:add <key>=<value> [<key2>=<value2> ...]"
			end

			vars = args.inject({}) do |vars, arg|
				key, value = arg.split('=')
				vars[key] = value
				vars
			end

			display "Setting #{vars.inspect} and restarting app...", false
			heroku.add_config_vars(app, vars)
			display "done."
		end

		def remove
			display "Unsetting #{args.first} and restarting app...", false
			heroku.remove_config_var(app, args.first)
			display "done."
		end

		def clear
			display "Reseting all config vars and restarting app...", false
			heroku.clear_config_vars(app)
			display "done."
		end

		protected
			def restart_app
				display "Restarting app...", false
				heroku.restart(app)
				display "done."
			end

			def display_vars(vars, long)
				max_length = vars.map { |v| v[0].size }.max
				vars.each do |k, v|
					spaces = ' ' * (max_length - k.size)
					display "#{k}#{spaces} => #{format(v, long)}"
				end
			end

			def format(value, long=false)
				return value if long || value.size < 36
				value[0, 16] + '...' + value[-16, 16]
			end
	end
end
