require "heroku/command/base"
require "heroku/api/domains_v3_domain_cname"

module Heroku::Command

  # manage custom domains
  #
  class Domains < Base

    # domains
    #
    # list custom domains for an app
    #
    #Examples:
    #
    # $ heroku domains
    # === Development Domain
    # example.herokuapp.com
    #
    # === Custom Domains
    # Domain Name  CNAME Target
    # -----------  ---------------------
    # example.com  example.herokudns.com
    #
    def index
      validate_arguments!
      domains = api.get_domains_v3_domain_cname(app).body

      styled_header("Development Domain")
      display domains.detect{ |d| d['kind'] == 'default' }['hostname']
      display

      custom_domains = domains.select{ |d| d['kind'] == 'custom' }
      if custom_domains.length > 0
        styled_header("Custom Domains")
        display_table(custom_domains, ['hostname', 'cname'], ['Domain Name', 'CNAME Target'])
      else
        display("#{app} has no custom domain names.")
      end
    end

    # domains:add DOMAIN
    #
    # add a custom domain to an app
    #
    #Examples:
    #
    # $ heroku domains:add example.com
    # Adding example.com to example... done
    #
    def add
      unless domain = shift_argument
        error("Usage: heroku domains:add DOMAIN\nMust specify DOMAIN to add.")
      end
      validate_arguments!
      action("Adding #{domain} to #{app}") do
        api.post_domain(app, domain)
      end
    end

    # domains:remove DOMAIN
    #
    # remove a custom domain from an app
    #
    #Examples:
    #
    # $ heroku domains:remove example.com
    # Removing example.com from example... done
    #
    def remove
      unless domain = shift_argument
        error("Usage: heroku domains:remove DOMAIN\nMust specify DOMAIN to remove.")
      end
      validate_arguments!
      action("Removing #{domain} from #{app}") do
        api.delete_domain(app, domain)
      end
    end

    # domains:clear
    #
    # remove all custom domains from an app
    #
    #Examples:
    #
    # $ heroku domains:clear
    # Removing all domain names for example... done
    #
    def clear
      validate_arguments!
      action("Removing all domain names from #{app}") do
        api.delete_domains(app)
      end
    end

  end
end
