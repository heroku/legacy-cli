require "heroku/helpers"

module Heroku
  module OpenSSL
    def self.generate_csr(domain, subject = nil, key_size = 2048)
      ensure_openssl_installed!
    
      keyfile = "#{domain}.key"
      csrfile = "#{domain}.csr"
  
      subj_args = if subject
        ['-subj', subject]
      else
        []
      end
  
      system("openssl", "req", "-new", "-newkey", "rsa:#{key_size}", "-nodes", "-keyout", keyfile, "-out", csrfile, *subj_args) or raise GenericError, "Key and CSR generation failed: #{$?}"
    
      return [keyfile, csrfile]
    end
  
    class GenericError < StandardError; end
  
    class NotInstalledError < GenericError
      include Heroku::Helpers
    
      def installation_hint
        if running_on_a_mac?
          "With Homebrew <http://brew.sh> installed, run the following command:\n$ brew install openssl"
        elsif running_on_windows?
          "Download and install OpenSSL from <http://slproweb.com/products/Win32OpenSSL.html>."
        else
          # Probably some kind of Linux or other Unix. Who knows what package manager they're using?
          "Make sure your package manager's 'openssl' package is installed."
        end
      end
    end
  
  private
    def self.ensure_openssl_installed!
      return if @checked
      system("openssl", "version") or raise NotInstalledError
      @checked = true
    end
  end
end
