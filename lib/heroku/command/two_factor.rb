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
      Heroku::JSPlugin.setup
      Heroku::JSPlugin.run('twofactor', nil, ARGV[1..-1])
    end

    alias_command "2fa", "twofactor"

    # twofactor:disable
    #
    # Disable two-factor authentication for your account
    #
    def disable
      Heroku::JSPlugin.setup
      Heroku::JSPlugin.run('twofactor', 'disable', ARGV[1..-1])
    end

    alias_command "2fa:disable", "twofactor:disable"


    # twofactor:generate-recovery-codes
    #
    # Generates and replaces recovery codes
    #
    def generate_recovery_codes
      Heroku::JSPlugin.setup
      Heroku::JSPlugin.run('twofactor', 'generate-recovery-codes', ARGV[1..-1])
    end

    alias_command "2fa:generate-recovery-codes", "twofactor:generate_recovery_codes"
  end
end
