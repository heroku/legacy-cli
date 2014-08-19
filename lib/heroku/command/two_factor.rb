require "heroku/command/base"

# manage two factor settings for account
#
module Heroku::Command
  class TwoFactor < BaseWithApp
    # 2fa
    #
    # Display whether two-factor is enabled or not
    #
    def index
      account = api.request(
        :expects => 200,
        :headers => { "Accept" => "application/vnd.heroku+json; version=3" },
        :method  => :get,
        :path    => "/account").body

      if account["two_factor_authentication"]
        display "Two-factor auth is enabled."
      else
        display "Two-factor is not enabled."
      end
    end

    alias_command "2fa", "twofactor"

    # 2fa:disable
    #
    # Disable 2fa on your account
    #
    def disable
      print "Password (typing will be hidden): "
      password = Heroku::Auth.ask_for_password

      update = MultiJson.encode(
        :two_factor_authentication => false,
        :password => password)

      api.request(
        :expects => 200,
        :headers => { "Accept" => "application/vnd.heroku+json; version=3" },
        :method  => :patch,
        :path    => "/account",
        :body    => update)
      display "Disabled two-factor authentication."
    rescue Heroku::API::Errors::RequestFailed => e
      error Heroku::Command.extract_error(e.response.body)
    end

    alias_command "2fa:disable", "twofactor:disable"


    # 2fa:generate-recovery-codes
    #
    # Generates (and replaces) recovery codes
    #
    def generate_recovery_codes
      code = Heroku::Auth.ask_for_second_factor

      recovery_codes = api.request(
        :expects => 200,
        :method  => :post,
        :path    => "/account/two-factor/recovery-codes",
        :headers => { "Heroku-Two-Factor-Code" => code }
      ).body

      display "Recovery codes:"
      recovery_codes.each { |c| display c }
    rescue RestClient::Unauthorized => e
      error Heroku::Command.extract_error(e.http_body)
    end

    alias_command "2fa:generate-recovery-codes", "twofactor:generate_recovery_codes"
  end
end
