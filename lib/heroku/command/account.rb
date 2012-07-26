require "heroku/command/base"

# manage heroku account options
#
class Heroku::Command::Account < Heroku::Command::Base

  # account:confirm_billing
  #
  # Confirm that your account can be billed at the end of the month
  #
  #Example:
  #
  # $ heroku account:confirm_billing
  # This action will cause your account to be billed at the end of the month
  # For more information, see http://docs.heroku.com/billing
  # Are you sure you want to do this? (y/n)
  #
  def confirm_billing
    validate_arguments!
    Heroku::Helpers.confirm_billing
  end

end
