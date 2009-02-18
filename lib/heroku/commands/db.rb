require 'taps/client_session'

module Heroku::Command
	class Db < BaseWithApp
		def pull
			database_url = args.shift
			database_url.strip!
			raise(CommandFailed) if database_url == ''

			taps_client(database_url, 1000) do |client|
				client.cmd_receive
			end
		end

		protected

		def taps_client(database_url, chunk_size, &block)
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
