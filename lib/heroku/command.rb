require 'heroku/helpers'
require 'heroku/plugin'
require 'heroku/builtin_plugin'
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
      @current_options
    end

    def self.global_options
      @global_options ||= []
    end

    def self.invalid_arguments
      @invalid_arguments
    end

    def self.shift_argument
      @invalid_arguments.shift.downcase rescue nil
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

    def self.global_option(name, *args, &blk)
      global_options << { :name => name, :args => args, :proc => blk }
    end

    global_option :app, "--app APP", "-a" do |app|
      raise OptionParser::InvalidOption.new(app) if app == "pp"
    end

    global_option :confirm, "--confirm APP"
    global_option :help,    "--help", "-h"
    global_option :remote,  "--remote REMOTE"

    def self.prepare_run(cmd, args=[])
      command = parse(cmd)

      unless command
        if %w( -v --version ).include?(cmd)
          display Heroku::VERSION
          exit
        end

        error([
          "`#{cmd}` is not a heroku command.",
          suggestion(cmd, commands.keys + command_aliases.keys),
          "See `heroku help` for additional details."
        ].compact.join("\n"))
      end

      @current_command = cmd

      opts = {}
      invalid_options = []

      parser = OptionParser.new do |parser|
        # overwrite OptionParsers Officious['version'] to avoid conflicts
        # see: https://github.com/ruby/ruby/blob/trunk/lib/optparse.rb#L814
        parser.on("--version") do |value|
          invalid_options << "--version"
        end
        global_options.each do |global_option|
          parser.on(*global_option[:args]) do |value|
            global_option[:proc].call(value) if global_option[:proc]
            opts[global_option[:name]] = value
          end
        end
        command[:options].each do |name, option|
          parser.on("-#{option[:short]}", "--#{option[:long]}", option[:desc]) do |value|
            opts[name.gsub("-", "_").to_sym] = value
          end
        end
      end

      begin
        parser.order!(args) do |nonopt|
          invalid_options << nonopt
        end
      rescue OptionParser::InvalidOption => ex
        invalid_options << ex.args.first
        retry
      end

      if opts[:help]
        args.unshift cmd unless cmd =~ /^-.*/
        cmd = "help"
        command = parse(cmd)
      end

      args.concat(invalid_options)

      @current_args = args
      @current_options = opts
      @invalid_arguments = invalid_options

      [ command[:klass].new(args.dup, opts.dup), command[:method] ]
    end

    def self.run(cmd, arguments=[])
      object, method = prepare_run(cmd, arguments.dup)
      object.send(method)
    rescue RestClient::Unauthorized, Heroku::API::Errors::Unauthorized
      puts "Authentication failure"
      unless ENV['HEROKU_API_KEY']
        run "login"
        retry
      end
    rescue RestClient::PaymentRequired, Heroku::API::Errors::VerificationRequired => e
      retry if run('account:confirm_billing', arguments.dup)
    rescue RestClient::ResourceNotFound => e
      error extract_error(e.http_body) {
        e.http_body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
      }
    rescue Heroku::API::Errors::NotFound => e
      error extract_error(e.response.body) {
        e.response.body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
      }
    rescue RestClient::Locked, Heroku::API::Errors::Locked => e
      app = e.response.headers[:x_confirmation_required]
      if confirm_command(app, extract_error(e.response.body))
        arguments << '--confirm' << app
        retry
      end
    rescue RestClient::RequestTimeout, Heroku::API::Errors::Timeout
      error "API request timed out. Please try again, or contact support@heroku.com if this issue persists."
    rescue RestClient::RequestFailed => e
      error extract_error(e.http_body)
    rescue Heroku::API::Errors::ErrorWithResponse => e
      error extract_error(e.response.body)
    rescue CommandFailed => e
      error e.message
    rescue OptionParser::ParseError => ex
      commands[cmd] ? run("help", [cmd]) : run("help")
    end

    def self.parse(cmd)
      commands[cmd] || commands[command_aliases[cmd]]
    end

    def self.extract_error(body, options={})
      default_error = block_given? ? yield : "Internal server error.\nRun 'heroku status' to check for known platform issues."
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
      json ? json['error'] : nil
    end

    def self.parse_error_plain(body)
      return unless body.respond_to?(:headers) && body.headers[:content_type].to_s.include?("text/plain")
      body.to_s
    end
  end
end
