require 'commands/base'

module Heroku
	module Command
		class InvalidCommand < RuntimeError; end
		class CommandFailed  < RuntimeError; end

		class << self
			def run(command, args)
				run_internal(command, args)
			rescue InvalidCommand
				display usage
			rescue RestClient::Unauthorized
				display "Authentication failure"
			rescue RestClient::ResourceNotFound
				display "Resource not found.  (Did you mistype the app name?)"
			rescue RestClient::RequestFailed => e
				display extract_error(e.response)
			rescue CommandFailed => e
				display e.message
			end

			def run_internal(command, args)
				namespace, command = parse(command)
				require "commands/#{namespace}"
				klass = Heroku::Command.const_get(namespace.capitalize).new(args)
				raise InvalidCommand unless klass.respond_to?(command)
				klass.send(command)
			end

			def display(msg)
				puts(msg)
			end

			def parse(command)
				parts = command.split(':')
				case parts.size
					when 1
						if namespaces.include? command
							return command, 'index'
						else
							return 'app', command
						end
					when 2
						raise InvalidCommand unless namespaces.include? parts[0]
						return parts
					else
						raise InvalidCommand
				end
			end

			def namespaces
				@@namespaces ||= Dir["#{File.dirname(__FILE__)}/commands/*"].map do |namespace|
					namespace.gsub(/.*\//, '').gsub(/\.rb/, '')
				end
			end

			def extract_error(response)
				return "Not found" if response.code.to_i == 404

				msg = parse_error_xml(response.body) rescue ''
				msg = 'Internal server error' if msg.empty?
				msg
			end

			def usage
				usage = <<EOTXT
=== General Commands

  list                         # list your apps
  create [<name>]              # create a new app

  keys                         # show your user's public keys
  keys:add [<path to keyfile>] # add a public key
  keys:remove <keyname>        # remove a key by name (user@host)
  keys:clear                   # remove all keys

=== App Commands (execute inside a checkout directory)

  info                         # show app info, like web url and git repo
  rename <newname>             # rename the app

  sharing:add <email>          # add a collaborator
  sharing:remove <email>       # remove a collaborator

  domains:add <domain>         # add a custom domain name
  domains:remove <domain>      # remove a custom domain name
  domains:clear                # remove all custom domains

  rake <command>               # remotely execute a rake command
  console <command>            # remotely execute a single console command
  console                      # start an interactive console to the remote app

  restart                      # restart app servers
  logs                         # fetch recent log output for debugging

  bundles                      # list bundles for the app
  bundles:capture [<bundle>]   # capture a bundle of the app's code and data
  bundles:download             # download most recent app bundle as a tarball
  bundles:download <bundle>    # download the named bundle
  bundles:animate <bundle>     # animate a bundle into a new app
  bundles:destroy <bundle>     # destroy the named bundle

  destroy                      # destroy the app permanently

=== Example story:

  rails myapp
  cd myapp
  (...make edits...)
  git add .
  git commit -m "my new app"
  heroku create myapp
  git remote add heroku git@heroku.com:myapp.git
  git push heroku master
EOTXT
			end
		end
	end
end