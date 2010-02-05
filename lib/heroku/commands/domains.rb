module Heroku::Command
  class Domains < BaseWithApp
    def list
      domains = heroku.list_domains(app)
      if domains.empty?
        display "No domain names for #{app}.#{heroku.host}"
      else
        display "Domain names for #{app}.#{heroku.host}:"
        display domains.map { |d| d[:domain] }.join("\n")
      end
    end
    alias :index :list

    def add
      domain = args.shift.downcase rescue nil
      heroku.add_domain(app, domain)
      display "Added #{domain} as a custom domain name to #{app}.#{heroku.host}"
    end

    def remove
      domain = args.shift.downcase rescue nil
      heroku.remove_domain(app, domain)
      display "Removed #{domain} as a custom domain name to #{app}.#{heroku.host}"
    end

    def clear
      heroku.remove_domains(app)
      display "Removed all domain names for #{app}.#{heroku.host}"
    end
  end
end