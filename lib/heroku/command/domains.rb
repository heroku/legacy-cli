require "heroku/command/base"

module Heroku::Command

  # manage custom domains
  #
  class Domains < BaseWithApp

    # domains
    #
    # list custom domains for an app
    #
    def index
      domains = heroku.list_domains(app)
      if domains.empty?
        display "No domain names for #{app}.#{heroku.host}"
      else
        display "Domain names for #{app}.#{heroku.host}:"
        display domains.map { |d| d[:domain] }.join("\n")
      end
    end

    # domains:add DOMAIN
    #
    # add a custom domain to an app
    #
    def add
      domain = args.shift.downcase rescue nil
      heroku.add_domain(app, domain)
      display "Added #{domain} as a custom domain name to #{app}.#{heroku.host}"
    end

    # domains:remove DOMAIN
    #
    # remove a custom domain from an app
    #
    def remove
      domain = args.shift.downcase rescue nil
      heroku.remove_domain(app, domain)
      display "Removed #{domain} as a custom domain name to #{app}.#{heroku.host}"
    end

    # domains:clear
    #
    # remove all custom domains from an app
    #
    def clear
      heroku.remove_domains(app)
      display "Removed all domain names for #{app}.#{heroku.host}"
    end
  end
end
