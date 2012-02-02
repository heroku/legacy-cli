require "heroku/command/base"

# authentication (login, logout)
#
class Heroku::Command::Auth < Heroku::Command::Base

  # auth:login
  #
  # log in with your heroku credentials
  #
  def login
    Heroku::Auth.login
    display "Authentication successful."
  end

  alias_command "login", "auth:login"

  # auth:logout
  #
  # clear local authentication credentials
  #
  def logout
    Heroku::Auth.logout
    display "Local credentials cleared."
  end

  alias_command "logout", "auth:logout"

  # auth:token
  #
  # display your api token
  #
  def token
    display Heroku::Auth.api_key
  end

end

