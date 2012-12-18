require "heroku/command/base"

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
    # === Domain names for example
    # example.com
    #
    def index
      validate_arguments!
      domains = api.get_domains(app).body
      if domains.length > 0
        styled_header("#{app} Domain Names")
        styled_array domains.map {|domain| domain["domain"]}
      else
        display("#{app} has no domain names.")
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
