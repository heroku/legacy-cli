require "heroku/helpers"
require "tempfile"

module Heroku
  module OpenSSL
    def self.generate_csr(domain, subject, key_size = 2048)
      keyfile = "#{domain}.key"
      csrfile = "#{domain}.csr"
      
      openssl_req_new(keyfile, csrfile, subject, key_size) or raise GenericError, "Key and CSR generation failed: #{$?}"
      
      return [keyfile, csrfile]
    end
    
    def self.generate_self_signed_certificate(domain, subject, key_size = 2048)
      ensure_openssl_installed!
    
      keyfile = "#{domain}.key"
      crtfile = "#{domain}.crt"
      
      openssl_req_new(keyfile, crtfile, subject, key_size, "-x509") or raise GenericError, "Key and self-signed certificate generation failed: #{$?}"
      
      return [keyfile, nil, crtfile]
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
    def self.openssl_req_new(keyfile, outfile, subject, key_size, *args)
      ensure_openssl_installed!
      system("openssl", "req", "-new", "-newkey", "rsa:#{key_size}", "-nodes", "-keyout", keyfile, "-out", outfile, "-subj", subject, *args)
    end
  
    def self.ensure_openssl_installed!
      return if @checked
      system("openssl", "version") or raise NotInstalledError
      @checked = true
    end
  end
end
