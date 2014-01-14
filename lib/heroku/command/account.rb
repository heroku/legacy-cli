require "heroku/command/base"

# manage heroku account options
#
class Heroku::Command::Account < Heroku::Command::Base

  # account:confirm-billing
  #
  # DEPRECATED
  #
  def confirm_billing
    display "Billing confirmation is no longer necessary."
    display "For more info: https://devcenter.heroku.com/changelog-items/346"
  end

end
