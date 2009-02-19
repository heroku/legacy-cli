require 'taps/client_session'

module Heroku::Command
	class Db < BaseWithApp
		def pull
			database_url = args.shift
			database_url.strip!
			raise(CommandFailed) if database_url == ''

			taps_client(database_url) do |client|
				client.cmd_receive
			end
		end

		def push
			database_url = args.shift
			database_url.strip!
			raise(CommandFailed) if database_url == ''

			taps_client(database_url) do |client|
				client.cmd_send
			end
		end

		def reset
			if name = extract_option('--app')
				info = heroku.info(name)
				url  = info[:domain_name] || "http://#{info[:name]}.#{heroku.host}/"

				display("Warning: All data in the '#{name}' database will be erased and will not be recoverable.")
				display("Are you sure you wish to continue? (y/n)? ", false)
				if ask.downcase == 'y'
					heroku.database_reset(name)
					display "Database reset for '#{name}' (#{url})"
				end
			else
				display "Set the app you want to reset the database for by adding --app <app name> to this command"
			end
		end

		protected

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
	end
end
