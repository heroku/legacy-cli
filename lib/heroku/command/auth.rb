require "heroku/command/base"

# login, logout
#
class Heroku::Command::Auth < Heroku::Command::Base

  # login
  #
  # log in with your heroku credentials
  #
  def login
    Heroku::Auth.login
  end

  # logout
  #
  # clear local authentication credentials
  #
  def logout
    Heroku::Auth.logout
    display "Local credentials cleared."
  end

end

