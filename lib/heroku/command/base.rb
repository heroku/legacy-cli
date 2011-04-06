require "fileutils"
require "heroku/auth"
require "heroku/command"

class Heroku::Command::Base
  include Heroku::Helpers

  def self.namespace
    self.to_s.split("::").last.downcase
  end

  attr_reader :args
  attr_reader :options

  def initialize(args, options)
    @args = args
    @options = options
  end

protected

  def self.inherited(klass)
    Heroku::Command.register_namespace(
      :name => klass.namespace,
      :description => nil
    )
  end

  def self.method_added(method)
    return if self == Heroku::Command::Base
    return if self == Heroku::Command::BaseWithApp
    return if private_method_defined?(method)

    help = extract_help(*(caller.first.split(":")[0..1]))

    resolved_method = (method.to_s == "index") ? nil : method.to_s

    command = [ self.namespace, resolved_method ].compact.join(":")
    banner  = help.split("\n").first
    options = []

    Heroku::Command.register_command(
      :klass     => self,
      :method    => method,
      :namespace => self.namespace,
      :command   => command,
      :banner    => banner,
      :help      => help,
      :options   => options
    )
  end

  def self.extract_help(file, line)
    # puts "FILE: #{file}"
    # puts "LINE: #{line}"
<<HELP
# command [ARGS]
#
# This is some help text
#
# -s, --stack: Add to stack
HELP
  end

  def heroku
    Heroku::Auth.client
  end

  def extract_app(force=true)
    app = extract_option('--app', false)
    raise(CommandFailed, "You must specify an app name after --app") if app == false
    unless app
      app = extract_app_in_dir(Dir.pwd) ||
      raise(CommandFailed, "No app specified.\nRun this command from app folder or set it adding --app <app name>") if force
      @autodetected_app = true
    end
    app
  end

  def extract_app_in_dir(dir)
    return unless remotes = git_remotes(dir)

    if remote = extract_option('--remote')
      remotes[remote]
    elsif remote = extract_app_from_git_config
      remotes[remote]
    else
      apps = remotes.values.uniq
      return apps.first if apps.size == 1
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

    git("remote -v").split("\n").each do |remote|
      name, url, method = remote.split(/\s/)
      if url =~ /^git@#{heroku.host}:([\w\d-]+)\.git$/
        remotes[name] = $1
      end
    end

    Dir.chdir(original_dir)
    remotes
  end

  def extract_option(options, default=true)
    values = options.is_a?(Array) ? options : [options]
    return unless opt_index = args.select { |a| values.include? a }.first
    opt_position = args.index(opt_index) + 1
    if args.size > opt_position && opt_value = args[opt_position]
      if opt_value.include?('--')
        opt_value = nil
      else
        args.delete_at(opt_position)
      end
    end
    opt_value ||= default
    args.delete(opt_index)
    block_given? ? yield(opt_value) : opt_value
  end

  def web_url(name)
    "http://#{name}.#{heroku.host}/"
  end

  def git_url(name)
    "git@#{heroku.host}:#{name}.git"
  end

  def app_urls(name)
    "#{web_url(name)} | #{git_url(name)}"
  end

  def escape(value)
    heroku.escape(value)
  end
end

class Heroku::Command::BaseWithApp < Heroku::Command::Base
  attr_accessor :app

  def initialize(args, heroku=nil)
    super(args, heroku)
    @app ||= extract_app
  end
end
