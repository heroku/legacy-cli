require "heroku/helpers"
require "tempfile"

module Heroku
  module OpenSSL
    class CertificateRequest
      attr_accessor :domain, :subject, :key_size, :self_signed
      
      def initialize()
        @key_size = 2048
        @self_signed = false
        super
      end
      
      def generate
        if self_signed
          generate_self_signed_certificate
        else
          generate_csr
        end
      end
      
      def generate_csr
        keyfile = "#{domain}.key"
        csrfile = "#{domain}.csr"
      
        openssl_req_new(keyfile, csrfile) or raise GenericError, "Key and CSR generation failed: #{$?}"
      
        return [keyfile, csrfile]
      end
    
      def generate_self_signed_certificate
        keyfile = "#{domain}.key"
        crtfile = "#{domain}.crt"
      
        openssl_req_new(keyfile, crtfile, "-x509") or raise GenericError, "Key and self-signed certificate generation failed: #{$?}"
      
        return [keyfile, nil, crtfile]
      end
      
    private
      def openssl_req_new(keyfile, outfile, *args)
        Heroku::OpenSSL.ensure_openssl_installed!
        system("openssl", "req", "-new", "-newkey", "rsa:#{key_size}", "-nodes", "-keyout", keyfile, "-out", outfile, "-subj", subject, *args)
      end
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
    
    def self.ensure_openssl_installed!
      return if @checked
      system("openssl", "version") or raise NotInstalledError
      @checked = true
    end
  end
end
