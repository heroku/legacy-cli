require "heroku/command/base"

module Heroku::Command

  # DEPRECATED: see `heroku certs` instead
  #
  # manage ssl certificates for an app
  #
  class Ssl < Base

    # ssl
    #
    # list legacy certificates for an app
    #
    def index
      api.get_domains(app).body.each do |domain|
        if cert = domain['cert']
          display "#{domain['domain']} has a SSL certificate registered to #{cert['subject']} which expires on #{format_date(cert['expires_at'])}"
        else
          display "#{domain['domain']} has no certificate"
        end
      end
    end

    # ssl:add PEM KEY
    #
    # DEPRECATED: see `heroku certs:add` instead
    #
    def add
      $stderr.puts " !    `heroku ssl:add` has been deprecated. Please use the SSL Endpoint add-on and the `heroku certs` commands instead."
      $stderr.puts " !    SSL Endpoint documentation is available at: https://devcenter.heroku.com/articles/ssl-endpoint"
    end

    # ssl:clear
    #
    # remove legacy ssl certificates from an app
    #
    def clear
      heroku.clear_ssl(app)
      display "Cleared certificates for #{app}"
    end
  end
end
