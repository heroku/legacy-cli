require 'heroku/helpers'
require 'heroku/plugin'
require 'heroku/builtin_plugin'
#require 'heroku/commands/base'
require 'vendor/okjson'

#Dir["#{File.dirname(__FILE__)}/commands/*.rb"].each { |c| require c }

module Heroku
  module Command
    class InvalidCommand < RuntimeError; end
    class CommandFailed  < RuntimeError; end

    extend Heroku::Helpers

    def self.load
      Dir[File.join(File.dirname(__FILE__), "command", "*.rb")].each do |file|
        require file
      end
    end

    def self.commands
      @@commands ||= {}
    end

    def self.namespaces
      @@namespaces ||= {}
    end

    def self.register_command(command)
      namespace = command[:klass].namespace
      name = command[:method].to_s == "index" ? nil : command[:method]
      commands[command[:command]] = command
    end

    def self.register_namespace(namespace)
      namespaces[namespace[:name]] = namespace
    end

    def self.optparse_class(value)
      case value
        when FalseClass then TrueClass
        else value.class
      end
    end

    def self.current_command
      @current_command
    end

    def self.run(cmd, args=[])
      command = parse(cmd)

      @current_command = cmd

      opts = command[:options].inject({}) do |hash, (name, option)|
        hash.update(name.to_sym => option[:default])
      end

      OptionParser.new do |parser|
        parser.on("-a", "--app APP") do |value|
          opts[:app] = value
        end
        parser.on("--confirm APP") do |value|
          opts[:confirm] = value
        end
        parser.on("-r", "--remote REMOTE") do |value|
          opts[:remote] = value
        end
        command[:options].each do |name, option|
          parser.on("-#{option[:short]}", "--#{option[:long]}", option[:desc]) do |value|
            opts[name.to_sym] = value
          end
        end
      end.parse!(args)
      object = command[:klass].new(args, opts)
      object.send(command[:method])
    rescue OptionParser::ParseError => ex
      puts ex.message
      run "help", [cmd]
    rescue InvalidCommand
      error "Unknown command. Run 'heroku help' for usage information."
    rescue RestClient::Unauthorized
      puts "Authentication failure"
      run "login"
      retry
    rescue RestClient::PaymentRequired => e
      retry if run('account:confirm_billing', args.dup)
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

    def self.parse(cmd)
      commands[cmd] || commands["help"]
    end

    def self.extract_not_found(body)
      body =~ /^[\w\s]+ not found$/ ? body : "Resource not found"
    end

    def self.extract_error(body)
      msg = parse_error_xml(body) || parse_error_json(body) || parse_error_plain(body) || 'Internal server error'
      msg.split("\n").map { |line| ' !   ' + line }.join("\n")
    end

    def self.parse_error_xml(body)
      xml_errors = REXML::Document.new(body).elements.to_a("//errors/error")
      msg = xml_errors.map { |a| a.text }.join(" / ")
      return msg unless msg.empty?
    rescue Exception
    end

    def self.parse_error_json(body)
      json = OkJson.decode(body.to_s)
      json['error']
    rescue OkJson::ParserError
    end

    def self.parse_error_plain(body)
      return unless body.respond_to?(:headers) && body.headers[:content_type].include?("text/plain")
      body.to_s
    end
  end
end
