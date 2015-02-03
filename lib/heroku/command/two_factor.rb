require "heroku/command/base"

module Heroku::Command
  # manage two-factor authentication settings
  #
  class TwoFactor < BaseWithApp
    # twofactor
    #
    # Display whether two-factor authentication is enabled or not
    #
    def index
      account = api.request(
        :expects => 200,
        :headers => { "Accept" => "application/vnd.heroku+json; version=3" },
        :method  => :get,
        :path    => "/account").body

      if account["two_factor_authentication"]
        display "Two-factor authentication is enabled."
      else
        display "Two-factor authentication is not enabled."
      end
    end

    alias_command "2fa", "twofactor"

    # twofactor:disable
    #
    # Disable two-factor authentication for your account
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


    # twofactor:generate-recovery-codes
    #
    # Generates and replaces recovery codes
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
