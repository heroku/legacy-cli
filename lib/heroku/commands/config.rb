module Heroku::Command
	class Config < BaseWithApp
		def index
			long = args.delete('--long')
			if args.empty?
				vars = heroku.config_vars(app)
				display_vars(vars, long)
			elsif args.size == 1 && !args.first.include?('=')
				var = heroku.config_vars(app).select { |k, v| k == args.first.upcase }
				display_vars(var, long)
			elsif args.all? { |a| a.include?('=') }
				args.map { |a| a.split('=') }.each do |k, v|
					heroku.set_config_var(app, k, v)
				end
				restart_app
			else
				raise CommandFailed, "Usage: heroku config <key> or heroku config <key>=<value>"
			end
		end

		def unset
			args.each { |k| heroku.unset_config_var(app, k) }
			display "Config variables #{args.join(' ')} were removed from #{app}"
			restart_app
		end

		def reset
			heroku.reset_config_vars(app)
			display "Config vars reset for #{app}"
			restart_app
		end

		protected
			def restart_app
				display "App is now restarting"
				heroku.restart(app)
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
