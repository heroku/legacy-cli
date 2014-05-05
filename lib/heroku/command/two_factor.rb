# encoding: utf-8

require "heroku/command/base"
require "rqrcode"
require "term/ansicolor"

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

    # 2fa:enable
    #
    # Enable 2fa on your account
    #
    # --browser # display QR code in a browser for better compatiblity
    #
    def enable
      display "WARN: this will change your API key, and expire it every 30 days!"

      url = api.request(
        :expects => 200,
        :method  => :post,
        :path    => "/account/two-factor/url"
      ).body["url"]

      if options[:browser]
        open_qrcode_in_browser(url)
      else
        render_qrcode(url)
      end

      display "Re-authenticate with code to activate two-factor."

      # ask for credentials again, this time storing the password in memory
      Heroku::Auth.credentials = Heroku::Auth.ask_for_credentials(true)

      # make the actual API call to enable two factor
      api.request(
        :expects => 200,
        :method  => :put,
        :path    => "/account/two-factor",
        :headers => { "Heroku-Two-Factor-Code" => Heroku::Auth.two_factor_code }
      )

      # get a new api key using the password and two factor
      new_api_key = Heroku::Auth.api_key(
        Heroku::Auth.user, Heroku::Auth.current_session_password)

      # store new api key to disk
      Heroku::Auth.credentials = [Heroku::Auth.user, new_api_key]
      Heroku::Auth.write_credentials

      display "Enabled two-factor authentication."
      display "Please generate recovery codes with `heroku 2fa:generate-recovery-codes`."
    ensure
      # make sure to clean file containing js file (for browser)
      if options[:browser]
        File.delete(js_code_file) rescue Errno::ENOENT
      end
    end

    alias_command "2fa:enable", "twofactor:enable"

    # 2fa:disable
    #
    # Disable 2fa on your account
    #
    def disable
      Heroku::Auth.safe_ask_for_password
      api.request(
        :expects => 200,
        :method  => :delete,
        :path    => "/account/two-factor",
        :headers => { "Heroku-Password" => Heroku::Auth.current_session_password }
      )
      display "Disabled two-factor authentication."
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

    protected

    def open_qrcode_in_browser(url)
      require "launchy"
      display "To enable scan the QR code opened in your browser and login below."
      File.open(js_code_file, "w") { |f| f.puts "var code = '#{url}';" }
      Launchy.open("#{support_path}/qrcode.html")
    end

    def render_qrcode(url)
      display "To enable scan the QR rendered below then login again."
      qr = RQRCode::QRCode.new(url, :size => 4, :level => :l)

      # qr.to_s doesn't work unfortunately. bringing that
      # over, and using two characters per position instead
      color = Term::ANSIColor
      white = color.white { "██" }
      black = color.black { "██" }
      line  = white * (qr.module_count + 2)

      code = qr.modules.map do |row|
        contents = row.map do |col|
          col ? black : white
        end.join
        white + contents + white
      end.join("\n")

      puts line
      puts code
      puts line
      puts "If you can't scan this qrcode please use 2fa:enable --browser."
      puts
    end

    def support_path
      File.expand_path('../../../../support', __FILE__)
    end

    def js_code_file
      "#{support_path}/code.js"
    end
  end
end
