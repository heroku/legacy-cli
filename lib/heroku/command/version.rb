require "heroku/command/base"
require "heroku/version"

# display version
#
class Heroku::Command::Version < Heroku::Command::Base

  # version
  #
  # show heroku client version
  #
  #Example:
  #
  # $ heroku version
  # v1.2.3
  #
  def index
    display(Heroku::VERSION)
  end

end
