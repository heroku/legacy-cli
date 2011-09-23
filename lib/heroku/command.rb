require 'heroku/helpers'
require 'heroku/plugin'
require 'heroku/builtin_plugin'
require "optparse"

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
      Heroku::Plugin.load!
    end

    def self.commands
      @@commands ||= {}
    end

    def self.command_aliases
      @@command_aliases ||= {}
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

    def self.current_args
      @current_args
    end

    def self.current_options
      @current_options
    end

    def self.global_options
      @global_options ||= []
    end

    def self.global_option(name, *args)
      global_options << { :name => name, :args => args }
    end

    global_option :app,     "--app APP", "-a"
    global_option :confirm, "--confirm APP"
    global_option :help,    "--help", "-h"
    global_option :remote,  "--remote REMOTE"

    def self.prepare_run(cmd, args=[])
      command = parse(cmd)

      unless command
        error " !   #{cmd} is not a heroku command. See 'heroku help'."
        return
      end

      @current_command = cmd

      opts = {}
      invalid_options = []

      parser = OptionParser.new do |parser|
        global_options.each do |global_option|
          parser.on(*global_option[:args]) do |value|
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

      raise OptionParser::ParseError if opts[:help]

      args.concat(invalid_options)

      @current_args = args
      @current_options = opts

      [ command[:klass].new(args.dup, opts.dup), command[:method] ]
    end

    def self.run(cmd, arguments=[])
      object, method = prepare_run(cmd, arguments.dup)
      object.send(method)
    rescue InvalidCommand
      error "Unknown command. Run 'heroku help' for usage information."
    rescue RestClient::Unauthorized
      puts "Authentication failure"
      run "login"
      retry
    rescue RestClient::PaymentRequired => e
      retry if run('account:confirm_billing', arguments.dup)
    rescue RestClient::ResourceNotFound => e
      error extract_error(e.http_body) {
        e.http_body =~ /^[\w\s]+ not found$/ ? e.http_body : "Resource not found"
      }
    rescue RestClient::Locked => e
      app = e.response.headers[:x_confirmation_required]
      message = extract_error(e.response.body)
      if confirmation_required(app, message)
        arguments << '--confirm' << app
        retry
      end
    rescue RestClient::RequestFailed => e
      error extract_error(e.http_body)
    rescue RestClient::RequestTimeout
      error "API request timed out. Please try again, or contact support@heroku.com if this issue persists."
    rescue CommandFailed => e
      error e.message
    rescue OptionParser::ParseError => ex
      commands[cmd] ? run("help", [cmd]) : run("help")
    rescue Interrupt => e
      error "\n[canceled]"
    end

    def self.parse(cmd)
      commands[cmd] || commands[command_aliases[cmd]]
    end

    def self.extract_error(body, options={})
      default_error = block_given? ? yield : "Internal server error"
      msg = parse_error_xml(body) || parse_error_json(body) || parse_error_plain(body) || default_error

      return msg if options[:raw]
      msg.split("\n").map { |line| ' !   ' + line }.join("\n")
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

    def self.confirmation_required(app, message)
      display
      display
      display message
      display " !    To proceed, type \"#{app}\" or re-run this command with --confirm #{app}"
      display
      display "> ", false
      if ask.downcase != app
        display " !    Input did not match #{app}. Aborted."
        false
      else
        true
      end
    end
  end
end
