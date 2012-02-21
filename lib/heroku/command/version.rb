require "heroku/command/base"
require "heroku/version"

# display version
#
class Heroku::Command::Version < Heroku::Command::Base

  # version
  #
  # show heroku client version
  #
  def index
    display Heroku::VERSION
  end

end
