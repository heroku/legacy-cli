require "heroku/command/base"

module Heroku::Command
  class TwoFactor < BaseWithApp
    # 2fa
    #
    # Display whether two-factor is enabled or not
    #
    def index
      status = api.request(
        :expects => 200,
        :method  => :get,
        :path    => "/account/two-factor"
      ).body

      if status["enabled"]
        display "Two-factor auth is enabled."
      else
        display "Two-factor is not enabled."
      end
    end

    alias_command "2fa", "twofactor"

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
