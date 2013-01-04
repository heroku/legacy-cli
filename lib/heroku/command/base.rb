require "fileutils"
require "heroku/auth"
require "heroku/client/rendezvous"
require "heroku/command"

class Heroku::Command::Base
  include Heroku::Helpers

  def self.namespace
    self.to_s.split("::").last.downcase
  end

  attr_reader :args
  attr_reader :options

  def initialize(args=[], options={})
    @args = args
    @options = options
  end

  def app
    @app ||= if options[:confirm].is_a?(String)
      if options[:app] && (options[:app] != options[:confirm])
        error("Mismatch between --app and --confirm")
      end
      options[:confirm]
    elsif options[:app].is_a?(String)
      options[:app]
    elsif ENV.has_key?('HEROKU_APP')
      ENV['HEROKU_APP']
    elsif app_from_dir = extract_app_in_dir(Dir.pwd)
      app_from_dir
    else
      # raise instead of using error command to enable rescuing when app is optional
      raise Heroku::Command::CommandFailed.new("No app specified.\nRun this command from an app folder or specify which app to use with --app APP.")
    end
  end

  def api
    Heroku::Auth.api
  end

  def heroku
    Heroku::Auth.client
  end

protected

  def self.inherited(klass)
    unless klass == Heroku::Command::Base
      help = extract_help_from_caller(caller.first)

      Heroku::Command.register_namespace(
        :name => klass.namespace,
        :description => help.first
      )
    end
  end

  def self.method_added(method)
    return if self == Heroku::Command::Base
    return if private_method_defined?(method)
    return if protected_method_defined?(method)

    help = extract_help_from_caller(caller.first)
    resolved_method = (method.to_s == "index") ? nil : method.to_s
    command = [ self.namespace, resolved_method ].compact.join(":")
    banner = extract_banner(help) || command

    Heroku::Command.register_command(
      :klass       => self,
      :method      => method,
      :namespace   => self.namespace,
      :command     => command,
      :banner      => banner.strip,
      :help        => help.join("\n"),
      :summary     => extract_summary(help),
      :description => extract_description(help),
      :options     => extract_options(help)
    )
  end

  def self.alias_command(new, old)
    raise "no such command: #{old}" unless Heroku::Command.commands[old]
    Heroku::Command.command_aliases[new] = old
  end

  def extract_app
    output_with_bang "Command::Base#extract_app has been deprecated. Please use Command::Base#app instead.  #{caller.first}"
    app
  end

  #
  # Parse the caller format and identify the file and line number as identified
  # in : http://www.ruby-doc.org/core/classes/Kernel.html#M001397.  This will
  # look for a colon followed by a digit as the delimiter.  The biggest
  # complication is windows paths, which have a color after the drive letter.
  # This regex will match paths as anything from the beginning to a colon
  # directly followed by a number (the line number).
  #
  # Examples of the caller format :
  # * c:/Ruby192/lib/.../lib/heroku/command/addons.rb:8:in `<module:Command>'
  # * c:/Ruby192/lib/.../heroku-2.0.1/lib/heroku/command/pg.rb:96:in `<class:Pg>'
  # * /Users/ph7/...../xray-1.1/lib/xray/thread_dump_signal_handler.rb:9
  #
  def self.extract_help_from_caller(line)
    # pull out of the caller the information for the file path and line number
    if line =~ /^(.+?):(\d+)/
      extract_help($1, $2)
    else
      raise("unable to extract help from caller: #{line}")
    end
  end

  def self.extract_help(file, line_number)
    buffer = []
    lines = Heroku::Command.files[file]

    (line_number.to_i-2).downto(0) do |i|
      line = lines[i]
      case line[0..0]
        when ""
        when "#"
          buffer.unshift(line[1..-1])
        else
          break
      end
    end

    buffer
  end

  def self.extract_banner(help)
    help.first
  end

  def self.extract_summary(help)
    extract_description(help).split("\n")[2].to_s.split("\n").first
  end

  def self.extract_description(help)
    help.reject do |line|
      line =~ /^\s+-(.+)#(.+)/
    end.join("\n")
  end

  def self.extract_options(help)
    help.select do |line|
      line =~ /^\s+-(.+)#(.+)/
    end.inject([]) do |options, line|
      args = line.split('#', 2).first
      args = args.split(/,\s*/).map {|arg| arg.strip}.sort.reverse
      name = args.last.split(' ', 2).first[2..-1]
      options << { :name => name, :args => args }
    end
  end

  def current_command
    Heroku::Command.current_command
  end

  def extract_option(key)
    options[key.dup.gsub('-','_').to_sym]
  end

  def invalid_arguments
    Heroku::Command.invalid_arguments
  end

  def shift_argument
    Heroku::Command.shift_argument
  end

  def validate_arguments!
    Heroku::Command.validate_arguments!
  end

  def extract_app_in_dir(dir)
    return unless remotes = git_remotes(dir)

    if remote = options[:remote]
      remotes[remote]
    elsif remote = extract_app_from_git_config
      remotes[remote]
    else
      apps = remotes.values.uniq
      if apps.size == 1
        apps.first
      else
        raise(Heroku::Command::CommandFailed, "Multiple apps in folder and no app specified.\nSpecify app with --app APP.")
      end
    end
  end

  def extract_app_from_git_config
    remote = git("config heroku.remote")
    remote == "" ? nil : remote
  end

  def git_remotes(base_dir=Dir.pwd)
    remotes = {}
    original_dir = Dir.pwd
    Dir.chdir(base_dir)

    return unless File.exists?(".git")
    git("remote -v").split("\n").each do |remote|
      name, url, method = remote.split(/\s/)
      if url =~ /^git@#{Heroku::Auth.git_host}(?:[\.\w]*):([\w\d-]+)\.git$/
        remotes[name] = $1
      end
    end

    Dir.chdir(original_dir)
    if remotes.empty?
      nil
    else
      remotes
    end
  end

  def escape(value)
    heroku.escape(value)
  end
end

module Heroku::Command
  unless const_defined?(:BaseWithApp)
    BaseWithApp = Base
  end
end
