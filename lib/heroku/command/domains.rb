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
    # Domain Name  DNS Target
    # -----------  ---------------------
    # example.com  example.herokudns.com
    #
    def index
      validate_arguments!
      domains = api.get_domains_v3_domain_cname(app).body

      styled_header("Development Domain")
      default_domain = domains.detect { |d| d['kind'] == 'default' }
      if default_domain
        display default_domain['hostname']
      else
        output_with_bang "Not found"
      end

      display

      styled_header("Custom Domains")
      custom_domains = domains.select{ |d| d['kind'] == 'custom' }
      if custom_domains.length > 0
        display_table(custom_domains, ['hostname', 'cname'], ['Domain Name', 'DNS Target'])
      else
        display("#{app} has no custom domains.")
        display("Use `heroku domains:add DOMAIN` to add one.")
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
    # !   Configure your application’s DNS to point to example.herokudns.com
    # !   For help with custom domains, see https://devcenter.heroku.com/articles/custom-domains
    #
    def add
      unless domain = shift_argument
        error("Usage: heroku domains:add DOMAIN\nMust specify DOMAIN to add.")
      end
      validate_arguments!
      domain = action("Adding #{domain} to #{app}") do
        api.post_domains_v3_domain_cname(app, domain).body
      end
      output_with_bang "Configure your application's DNS to point to #{domain['cname']}"
      output_with_bang "For help, see https://devcenter.heroku.com/articles/custom-domains"
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
