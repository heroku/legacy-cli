load('heroku/helpers.rb') # reload helpers after possible inject_loadpath
load('heroku/updater.rb') # reload updater after possible inject_loadpath

# exists and updated in the last 5 minutes
if File.exist?(Heroku::Updater.updating_lock_path) &&
    File.mtime(Heroku::Updater.updating_lock_path) > (Time.now - 5*60)
  $stderr.puts "Heroku Toolbelt is currently updating. Please wait a few seconds and try your command again."
  exit 1
end

require "heroku"
require "heroku/command"
require "heroku/helpers"
require 'rest_client'
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
    begin
      if $stdin.isatty
        $stdin.sync = true
      end
      if $stdout.isatty
        $stdout.sync = true
      end
      command = args.shift.strip rescue "help"
      Heroku::Command.load
      Heroku::Command.run(command, args)
    rescue Interrupt => e
      `stty icanon echo`
      if ENV["HEROKU_DEBUG"]
        styled_error(e)
      else
        error("Command cancelled.")
      end
    rescue => error
      styled_error(error)
      exit(1)
    end
  end

end
