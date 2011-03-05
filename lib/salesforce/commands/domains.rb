module Salesforce::Command
  class Domains < BaseWithApp
    def list
      domains = salesforce.list_domains(app)
      if domains.empty?
        display "No domain names for #{app}.#{salesforce.host}"
      else
        display "Domain names for #{app}.#{salesforce.host}:"
        display domains.map { |d| d[:domain] }.join("\n")
      end
    end
    alias :index :list

    def add
      domain = args.shift.downcase rescue nil
      salesforce.add_domain(app, domain)
      display "Added #{domain} as a custom domain name to #{app}.#{salesforce.host}"
    end

    def remove
      domain = args.shift.downcase rescue nil
      salesforce.remove_domain(app, domain)
      display "Removed #{domain} as a custom domain name to #{app}.#{salesforce.host}"
    end

    def clear
      salesforce.remove_domains(app)
      display "Removed all domain names for #{app}.#{salesforce.host}"
    end
  end
end
