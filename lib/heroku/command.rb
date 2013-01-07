require 'heroku/helpers'
require 'heroku/plugin'
require 'heroku/version'
require "optparse"

module Heroku
  module Command
    class CommandFailed  < RuntimeError; end

    extend Heroku::Helpers

    def self.load
      Dir[File.join(File.dirname(__FILE__), "command", "*.rb")].each do |file|
        require file
      end
      Heroku::Plugin.load!
    end

    def self.commands
      @@commands ||= {}
    end

    def self.command_aliases
      @@command_aliases ||= {}
    end

    def self.files
      @@files ||= Hash.new {|hash,key| hash[key] = File.readlines(key).map {|line| line.strip}}
    end

    def self.namespaces
      @@namespaces ||= {}
    end

    def self.register_command(command)
      commands[command[:command]] = command
    end

    def self.register_namespace(namespace)
      namespaces[namespace[:name]] = namespace
    end

    def self.current_command
      @current_command
    end

    def self.current_command=(new_current_command)
      @current_command = new_current_command
    end

    def self.current_args
      @current_args
    end

    def self.current_options
      @current_options ||= {}
    end

    def self.global_options
      @global_options ||= []
    end

    def self.invalid_arguments
      @invalid_arguments
    end

    def self.shift_argument
      # dup argument to get a non-frozen string
      @invalid_arguments.shift.dup rescue nil
    end

    def self.validate_arguments!
      unless invalid_arguments.empty?
        arguments = invalid_arguments.map {|arg| "\"#{arg}\""}
        if arguments.length == 1
          message = "Invalid argument: #{arguments.first}"
        elsif arguments.length > 1
          message = "Invalid arguments: "
          message << arguments[0...-1].join(", ")
          message << " and "
          message << arguments[-1]
        end
        $stderr.puts(format_with_bang(message))
        run(current_command, ["--help"])
        exit(1)
      end
    end

    def self.warnings
      @warnings ||= []
    end

    def self.display_warnings
      unless warnings.empty?
        $stderr.puts(warnings.map {|warning| " !    #{warning}"}.join("\n"))
      end
    end

    def self.global_option(name, *args, &blk)
      # args.sort.reverse gives -l, --long order
      global_options << { :name => name.to_s, :args => args.sort.reverse, :proc => blk }
    end

    global_option :app, "-a", "--app APP" do |app|
      raise OptionParser::InvalidOption.new(app) if app == "pp"
    end

    global_option :confirm, "--confirm APP"
    global_option :help,    "-h", "--help"
    global_option :remote,  "-r", "--remote REMOTE"
    global_option :region,  "--region REGION"

    def self.prepare_run(cmd, args=[])
      command = parse(cmd)

      if args.include?('-h') || args.include?('--help')
        args.unshift(cmd) unless cmd =~ /^-.*/
        cmd = 'help'
        command = parse(cmd)
      end

      if cmd == '--version'
        cmd = 'version'
        command = parse(cmd)
      end

      @current_command = cmd
      @anonymized_args, @normalized_args = [], []

      opts = {}
      invalid_options = []

      parser = OptionParser.new do |parser|
        # remove OptionParsers Officious['version'] to avoid conflicts
        # see: https://github.com/ruby/ruby/blob/trunk/lib/optparse.rb#L814
        parser.base.long.delete('version')
        (global_options + (command && command[:options] || [])).each do |option|
          parser.on(*option[:args]) do |value|
            if option[:proc]
              option[:proc].call(value)
            end
            opts[option[:name].gsub('-', '_').to_sym] = value
            ARGV.join(' ') =~ /(#{option[:args].map {|arg| arg.split(' ', 2).first}.join('|')})/
            @anonymized_args << "#{$1} _"
            @normalized_args << "#{option[:args].last.split(' ', 2).first} _"
          end
        end
      end

      begin
        parser.order!(args) do |nonopt|
          invalid_options << nonopt
          @anonymized_args << '!'
          @normalized_args << '!'
        end
      rescue OptionParser::InvalidOption => ex
        invalid_options << ex.args.first
        @anonymized_args << '!'
        @normalized_args << '!'
        retry
      end

      args.concat(invalid_options)

      @current_args = args
      @current_options = opts
      @invalid_arguments = invalid_options

      @anonymous_command = [ARGV.first, *@anonymized_args].join(' ')
      begin
        usage_directory = "#{home_directory}/.heroku/usage"
        FileUtils.mkdir_p(usage_directory)
        usage_file = usage_directory << "/#{Heroku::VERSION}"
        usage = if File.exists?(usage_file)
          json_decode(File.read(usage_file))
        else
          {}
        end
        usage[@anonymous_command] ||= 0
        usage[@anonymous_command] += 1
        File.write(usage_file, json_encode(usage) + "\n")
      rescue
        # usage writing is not important, allow failures
      end

      if command
        command_instance = command[:klass].new(args.dup, opts.dup)

        if !@normalized_args.include?('--app _') && (implied_app = command_instance.app rescue nil)
          @normalized_args << '--app _'
        end
        @normalized_command = [ARGV.first, @normalized_args.sort_by {|arg| arg.gsub('-', '')}].join(' ')

        [ command_instance, command[:method] ]
      else
        error([
          "`#{cmd}` is not a heroku command.",
          suggestion(cmd, commands.keys + command_aliases.keys),
          "See `heroku help` for a list of available commands."
        ].compact.join("\n"))
      end
    end

    def self.run(cmd, arguments=[])
      begin
        object, method = prepare_run(cmd, arguments.dup)
        object.send(method)
      rescue Interrupt, StandardError, SystemExit => error
        # load likely error classes, as they may not be loaded yet due to defered loads
        require 'heroku-api'
        require 'rest_client'
        raise(error)
      end
    rescue Heroku::API::Errors::Unauthorized, RestClient::Unauthorized
      puts "Authentication failure"
      unless ENV['HEROKU_API_KEY']
        run "login"
        retry
      end
    rescue Heroku::API::Errors::VerificationRequired, RestClient::PaymentRequired => e
      retry if Heroku::Helpers.confirm_billing
    rescue Heroku::API::Errors::NotFound => e
      error extract_error(e.response.body) {
        e.response.body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
      }
    rescue RestClient::ResourceNotFound => e
      error extract_error(e.http_body) {
        e.http_body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
      }
    rescue Heroku::API::Errors::Locked => e
      app = e.response.headers[:x_confirmation_required]
      if confirm_command(app, extract_error(e.response.body))
        arguments << '--confirm' << app
        retry
      end
    rescue RestClient::Locked => e
      app = e.response.headers[:x_confirmation_required]
      if confirm_command(app, extract_error(e.http_body))
        arguments << '--confirm' << app
        retry
      end
    rescue Heroku::API::Errors::Timeout, RestClient::RequestTimeout
      error "API request timed out. Please try again, or contact support@heroku.com if this issue persists."
    rescue Heroku::API::Errors::ErrorWithResponse => e
      error extract_error(e.response.body)
    rescue RestClient::RequestFailed => e
      error extract_error(e.http_body)
    rescue CommandFailed => e
      error e.message
    rescue OptionParser::ParseError
      commands[cmd] ? run("help", [cmd]) : run("help")
    rescue Excon::Errors::SocketError => e
      if e.message == 'getaddrinfo: nodename nor servname provided, or not known (SocketError)'
        error("Unable to connect to Heroku API, please check internet connectivity and try again.")
      else
        raise(e)
      end
    ensure
      display_warnings
    end

    def self.parse(cmd)
      commands[cmd] || commands[command_aliases[cmd]]
    end

    def self.extract_error(body, options={})
      default_error = block_given? ? yield : "Internal server error.\nRun `heroku status` to check for known platform issues."
      parse_error_xml(body) || parse_error_json(body) || parse_error_plain(body) || default_error
    end

    def self.parse_error_xml(body)
      xml_errors = REXML::Document.new(body).elements.to_a("//errors/error")
      msg = xml_errors.map { |a| a.text }.join(" / ")
      return msg unless msg.empty?
    rescue Exception
    end

    def self.parse_error_json(body)
      json = json_decode(body.to_s) rescue false
      case json
      when Array
        json.first.join(' ') # message like [['base', 'message']]
      when Hash
        json['error']   # message like {'error' => 'message'}
      else
        nil
      end
    end

    def self.parse_error_plain(body)
      return unless body.respond_to?(:headers) && body.headers[:content_type].to_s.include?("text/plain")
      body.to_s
    end
  end
end
