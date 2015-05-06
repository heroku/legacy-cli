require "heroku/command/base"

# check status of heroku platform
#
class Heroku::Command::Status < Heroku::Command::Base

  # status
  #
  # display current status of heroku platform
  #
  #Example:
  #
  # $ heroku status
  # === Heroku Status
  # Development: No known issues at this time.
  # Production:  No known issues at this time.
  #
  def index
    Heroku::JSPlugin.install('heroku-status')
    Heroku::JSPlugin.run('status', nil, ARGV[1..-1])
  end
end
