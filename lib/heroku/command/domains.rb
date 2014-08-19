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
      display ""
      dns_advice(app, domain)
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

    # domains:dns
    #
    # show correct DNS configuration for a given domain and app
    #
    #Examples:
    #
    # $ heroku domains:dns www.mysite.com
    # HTTP:   Domain should CNAME mysite.herokuapp.com
    # HTTPS:  Not enabled on this domain.  Add an SSL:Endpoint.
    #
    def dns
      unless domain = shift_argument
        error("Usage: heroku domains:add DOMAIN\nMust specify DOMAIN to get.")
      end
      validate_arguments!
      dns_advice(app, domain)
    end

    private

      def alias_type(domain)
        apex?(domain) ? "ALIAS" : "CNAME"
      end

      def dns_advice(app, domain)
        _app_info = app_info(app)
        return if _app_info[:domain].nil?
        _ssl_endpoints = ssl_endpoints(app)

        result = []

        if _ssl_endpoints.size > 0
          if _app_info[:region] == 'eu'
            result << ['HTTP & HTTPS:', "Domain should #{alias_type(domain)} #{_app_info[:domain]}"]
          else
            result << ['HTTP & HTTPS:', "Domain should #{alias_type(domain)} #{_ssl_endpoints.first}"]
          end
        else
          result << ['HTTP:', "Domain should #{alias_type(domain)} #{_app_info[:domain]}"]
          result << ['HTTPS:', "Not enabled on this domain.  Add an SSL:Endpoint."]
        end

        styled_array result

        if apex?(domain)
          display "Users of apex (root) domains should read https://devcenter.heroku.com/articles/apex-domains"
        end
      end

      def apex?(domain)
        uri = URI.parse("http://dominion-dns.herokuapp.com/base/#{domain}")
        base_domain = Net::HTTP.get(uri)
        domain == base_domain
      end

      def app_info(app)
        _info = api.get_app(app).body
        ret = {
              cedar: _info['stack'],
              region: _info['region']
            }
        ret[:domain] = _info['domain_name']['domain'] rescue nil
        return ret
      end

      def ssl_endpoints(app)
        begin
          _info = heroku.ssl_endpoint_list(app)
        rescue
          return {}
        end
        _info.collect{|ep| ep["cname"]}
      end

  end
end
