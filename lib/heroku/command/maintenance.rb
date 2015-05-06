require "heroku/command/base"

# manage maintenance mode for an app
#
class Heroku::Command::Maintenance < Heroku::Command::Base

  # maintenance
  #
  # display the current maintenance status of app
  #
  #Example:
  #
  # $ heroku maintenance
  # off
  #
  def index
    Heroku::JSPlugin.install('heroku-apps')
    Heroku::JSPlugin.run('maintenance', nil, ARGV[1..-1])
  end

  # maintenance:on
  #
  # put the app into maintenance mode
  #
  #Example:
  #
  # $ heroku maintenance:on
  # Enabling maintenance mode for example
  #
  def on
    Heroku::JSPlugin.install('heroku-apps')
    Heroku::JSPlugin.run('maintenance', 'on', ARGV[1..-1])
  end

  # maintenance:off
  #
  # take the app out of maintenance mode
  #
  #Example:
  #
  # $ heroku maintenance:off
  # Disabling maintenance mode for example
  #
  def off
    Heroku::JSPlugin.install('heroku-apps')
    Heroku::JSPlugin.run('maintenance', 'off', ARGV[1..-1])
  end

end
