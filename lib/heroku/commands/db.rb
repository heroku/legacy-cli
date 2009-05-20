module Heroku::Command
	class Db < BaseWithApp
		def pull
			database_url = args.shift.strip rescue ''
			if database_url == ''
				database_url = parse_database_yml
				display "Auto-detected local database: #{database_url}" if database_url != ''
			end
			raise(CommandFailed, "Invalid database url") if database_url == ''

			taps_client(database_url) do |client|
				client.cmd_receive
			end
		end

		def push
			database_url = args.shift.strip rescue ''
			if database_url == ''
				database_url = parse_database_yml
				display "Auto-detected local database: #{database_url}" if database_url != ''
			end
			raise(CommandFailed, "Invalid database url") if database_url == ''

			taps_client(database_url) do |client|
				client.cmd_send
			end
		end

		def reset
			if !autodetected_app
				info = heroku.info(app)
				url  = info[:domain_name] || "http://#{info[:name]}.#{heroku.host}/"

				display("Warning: All data in the '#{app}' database will be erased and will not be recoverable.")
				display("Are you sure you wish to continue? (y/n)? ", false)
				if ask.downcase == 'y'
					heroku.database_reset(app)
					display "Database reset for '#{app}' (#{url})"
				end
			else
				display "Set the app you want to reset the database for by adding --app <app name> to this command"
			end
		end

		protected

		def parse_database_yml
			return "" unless File.exists?(Dir.pwd + '/config/database.yml')

			conf = YAML.load(File.read(Dir.pwd + '/config/database.yml'))['development']
			case conf['adapter']
				when 'sqlite3'
					return "sqlite://#{conf['database']}"
				when 'postgresql'
					uri_hash = conf_to_uri_hash(conf)
					uri_hash['scheme'] = 'postgres'
					return uri_hash_to_url(uri_hash)
				else
					return uri_hash_to_url(conf_to_uri_hash(conf))
			end
		rescue Object => e
			""
		end

		def conf_to_uri_hash(conf)
			uri = {}
			uri['scheme'] = conf['adapter']
			uri['username'] = conf['user'] || conf['username']
			uri['password'] = conf['password']
			uri['host'] = conf['host'] || conf['hostname']
			uri['port'] = conf['port']
			uri['path'] = conf['database']

			conf['encoding'] = 'utf8' if conf['encoding'] == 'unicode' or conf['encoding'].nil?
			uri['query'] = "encoding=#{conf['encoding']}"

			uri
		end

		def uri_hash_to_url(uri)
			url = "#{uri['scheme']}://"
			if uri['username'].size
				url += escape(uri['username'])
				url += ':' + escape(uri['password']) if uri['password']
				url += "@"
			  url += uri['host'] || '127.0.0.1'
                        else
                          url += uri['host'] if uri['host']
                        end
			url += uri['port'] if uri['port']
			url += "/"
			url += uri['path']
			url += "?#{uri['query']}" if uri['query']
			url
		end

		def taps_client(database_url, &block)
			chunk_size = 1000
			Taps::Config.database_url = database_url
			Taps::Config.verify_database_url

			Taps::ClientSession.start(database_url, "http://heroku:osui59a24am79x@taps.#{heroku.host}", chunk_size) do |client|
				uri = heroku.database_session(app)
				client.set_session(uri)
				client.verify_server
				yield client
			end
		end

		def initialize(*args)
			super(*args)

			gem 'taps', '>= 0.2.8', '< 0.3.0'
			require 'taps/client_session'
		rescue LoadError
			error "Install the Taps gem to use db commands. On most systems this will be:\nsudo gem install taps"
		end
	end
end
