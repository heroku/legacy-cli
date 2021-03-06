require "heroku/command/base"

# authentication (login, logout)
#
class Heroku::Command::Auth < Heroku::Command::Base

  # auth:login
  #
  # log in with your heroku credentials
  #
  #Example:
  #
  # $ heroku auth:login
  # Enter your Heroku credentials:
  # Email: email@example.com
  # Password (typing will be hidden):
  # Authentication successful.
  #
  def login
    validate_arguments!

    Heroku::Auth.login
    display "Authentication successful."
  end

  alias_command "login", "auth:login"

  # auth:logout
  #
  # clear local authentication credentials
  #
  #Example:
  #
  # $ heroku auth:logout
  # Local credentials cleared.
  #
  def logout
    validate_arguments!

    Heroku::Auth.logout
    display "Local credentials cleared."
  end

  alias_command "logout", "auth:logout"

  # auth:token
  #
  # display your api token
  #
  #Example:
  #
  # $ heroku auth:token
  # ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789ABCD
  #
  def token
    validate_arguments!

    display Heroku::Auth.api_key
  end

  # auth:whoami
  #
  # display your heroku email address
  #
  #Example:
  #
  # $ heroku auth:whoami
  # email@example.com
  #
  def whoami
    Heroku::JSPlugin.setup
    Heroku::JSPlugin.run('whoami', nil, ARGV[1..-1])
  end
end
