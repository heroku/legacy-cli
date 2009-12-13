require 'commands/base'
require 'plugin'

module Heroku
	module Command
		class InvalidCommand < RuntimeError; end
		class CommandFailed  < RuntimeError; end

		class << self
			def run(command, args, retries=0)
				run_internal 'auth:reauthorize', args.dup if retries > 0
				run_internal(command, args.dup)
			rescue InvalidCommand
				error "Unknown command. Run 'heroku help' for usage information."
			rescue RestClient::Unauthorized
				if retries < 3
					STDERR.puts "Authentication failure"
					run(command, args, retries+1)
				else
					error "Authentication failure"
				end
			rescue RestClient::ResourceNotFound => e
				error extract_not_found(e.http_body)
			rescue RestClient::RequestFailed => e
				error extract_error(e.http_body)
			rescue RestClient::RequestTimeout
				error "API request timed out. Please try again, or contact support@heroku.com if this issue persists."
			rescue CommandFailed => e
				error e.message
			rescue Interrupt => e
				error "\n[canceled]"
			end

			def run_internal(command, args, heroku=nil)
				namespace, command = parse(command)
				require "commands/#{namespace}"
				klass = Heroku::Command.const_get(namespace.capitalize).new(args, heroku)
				raise InvalidCommand unless klass.respond_to?(command)
				klass.send(command)
			end

			def error(msg)
				STDERR.puts(msg)
				exit 1
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

			def extract_not_found(body)
				body =~ /^[\w\s]+ not found$/ ? body : "Resource not found"
			end

			def extract_error(body)
				msg = parse_error_xml(body)
				msg ||= parse_error_json(body)
				msg ||= 'Internal server error'
				msg
			end

			def parse_error_xml(body)
				xml_errors = REXML::Document.new(body).elements.to_a("//errors/error")
				msg = xml_errors.map { |a| a.text }.join(" / ")
				return msg unless msg.empty?
			rescue Exception
			end

			def parse_error_json(body)
				json = JSON.parse(body)
				json['error']
			rescue JSON::ParserError
			end
		end
	end
end
