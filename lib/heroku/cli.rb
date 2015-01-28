load('heroku/helpers.rb') # reload helpers after possible inject_loadpath
load('heroku/updater.rb') # reload updater after possible inject_loadpath

# exists and updated in the last 5 minutes
if File.exist?(Heroku::Updater.updating_lock_path) &&
    File.mtime(Heroku::Updater.updating_lock_path) > (Time.now - 5*60)
  $stderr.puts "Heroku Toolbelt is currently updating. Please wait a few seconds and try your command again."
  exit 1
end

require 'heroku'
require 'heroku/command'
require 'heroku/git'
require 'heroku/helpers'
require 'heroku/http_instrumentor'
require 'heroku/rollbar'
require 'rest_client'
require 'multi_json'
require 'heroku-api'

begin
  # attempt to load the JSON parser bundled with ruby for multi_json
  # we're doing this because several users apparently have gems broken
  # due to OS upgrades. see: https://github.com/heroku/heroku/issues/932
  require 'json'
rescue LoadError
  # let multi_json fallback to yajl/oj/okjson
end

class Heroku::CLI

  extend Heroku::Helpers

  def self.start(*args)
    $stdin.sync = true if $stdin.isatty
    $stdout.sync = true if $stdout.isatty
    Heroku::Git.check_git_version
    command = args.shift.strip rescue "help"
    Heroku::Command.load
    Heroku::Command.run(command, args)
    Heroku::Updater.autoupdate
  rescue Errno::EPIPE => e
    error(e.message)
  rescue Interrupt => e
    `stty icanon echo`
    if ENV["HEROKU_DEBUG"]
      styled_error(e)
    else
      error("Command cancelled.", false)
    end
  rescue => error
    styled_error(error)
    exit(1)
  end

end
