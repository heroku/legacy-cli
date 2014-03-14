load('heroku/helpers.rb') # reload helpers after possible inject_loadpath
load('heroku/updater.rb') # reload updater after possible inject_loadpath

require "heroku"
require "heroku/command"
require "heroku/helpers"

# workaround for rescue/reraise to define errors in command.rb failing in 1.8.6
if RUBY_VERSION =~ /^1.8.6/
  require('heroku-api')
  require('rest_client')
end

require "multi_json"

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
      setup_multi_json
      command = args.shift.strip rescue "help"
      Heroku::Command.load
      Heroku::Command.run(command, args)
    rescue Interrupt
      `stty icanon echo`
      error("Command cancelled.")
    rescue => error
      styled_error(error)
      exit(1)
    end
  end

  # we have several reports of issues with the json_common
  # adapter, just use ok_json instead of it. for more info:
  # https://github.com/heroku/heroku/issues/1019
  def self.setup_multi_json
    if MultiJson.engine == :json_common
      MultiJson.engine = :ok_json
    end
  end

end
