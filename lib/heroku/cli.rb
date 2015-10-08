if RUBY_VERSION < '1.9.0' # this is a string comparison, but it should work for any old ruby version
  $stderr.puts "Heroku Toolbelt requires Ruby 1.9+."
  exit 1
end

Encoding.default_internal, Encoding.default_external = ['utf-8'] * 2
load('heroku/helpers.rb') # reload helpers after possible inject_loadpath
load('heroku/updater.rb') # reload updater after possible inject_loadpath

require 'heroku'
require 'heroku/jsplugin'
require 'heroku/rollbar'
require 'json'

class Heroku::CLI

  extend Heroku::Helpers

  def self.start(*args)
    $stdin.sync = true if $stdin.isatty
    $stdout.sync = true if $stdout.isatty
    Heroku::Updater.warn_if_updating
    command = args.shift.strip rescue "help"
    Heroku::JSPlugin.setup
    Heroku::JSPlugin.try_takeover(command, args)
    require 'heroku/command'
    Heroku::Git.check_git_version
    Heroku::Command.load
    warn_if_using_heroku_accounts
    Heroku::Command.run(command, args)
    Heroku::Updater.autoupdate
  rescue Errno::EPIPE => e
    error(e.message)
  rescue Interrupt => e
    `stty icanon echo` unless running_on_windows?
    if ENV["HEROKU_DEBUG"]
      styled_error(e)
    else
      error("Command cancelled.", false)
    end
  rescue => error
    styled_error(error)
    exit(1)
  end

  def self.warn_if_using_heroku_accounts
    if defined?(Heroku::Command::Accounts.account)
      $stderr.print "Uninstalling deprecated ddollar/heroku-accounts plugin..."
      Heroku::Plugin.new('heroku-accounts').uninstall
      $stderr.puts " done"
    end
  end
end
