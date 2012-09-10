require "heroku/command/base"

# manage ssl endpoints for an app
#
class Heroku::Command::Certs < Heroku::Command::Base

  # certs
  #
  # list ssl endpoints for an app
  #
  def index
    endpoints = heroku.ssl_endpoint_list(app)

    if endpoints.empty?
      display "#{app} has no SSL Endpoints."
      display "Use `heroku certs:add PEM KEY` to add one."
    else
      endpoints.map! do |endpoint|
        {
          'cname'       => endpoint['cname'],
          'domains'     => endpoint['ssl_cert']['cert_domains'].join(', '),
          'expires_at'  => format_date(endpoint['ssl_cert']['expires_at']),
          'ca_signed?'  => endpoint['ssl_cert']['ca_signed?'].to_s.capitalize
        }
      end
      display_table(
        endpoints,
        %w( cname domains expires_at ca_signed? ),
        [ "Endpoint", "Common Name(s)", "Expires", "Trusted" ]
      )
    end
  end

  # certs:add PEM KEY
  #
  # add an ssl endpoint to an app
  #
  def add
    fail("Usage: heroku certs:add PEM KEY\nMust specify PEM and KEY to add cert.") if args.size < 2
    pem = File.read(args[0]) rescue error("Unable to read #{args[0]} PEM")
    key = File.read(args[1]) rescue error("Unable to read #{args[1]} KEY")

    endpoint = action("Adding SSL Endpoint to #{app}") do
      heroku.ssl_endpoint_add(app, pem, key)
    end

    display_warnings(endpoint)
    display "#{app} now served by #{endpoint['cname']}"
    display "Certificate details:"
    display_certificate_info(endpoint)
  end

  # certs:info
  #
  # show certificate information for an ssl endpoint
  #
  def info
    cname = options[:endpoint] || current_endpoint
    endpoint = action("Fetching SSL Endpoint #{cname} info for #{app}") do
      heroku.ssl_endpoint_info(app, cname)
    end

    display "Certificate details:"
    display_certificate_info(endpoint)
  end

  # certs:remove
  #
  # remove an SSL Endpoint from an app
  #
  def remove
    cname = options[:endpoint] || current_endpoint
    action("Removing SSL Endpoint #{cname} from #{app}") do
      heroku.ssl_endpoint_remove(app, cname)
    end
    display "NOTE: Billing is still active. Remove SSL Endpoint add-on to stop billing."
  end

  # certs:update PEM KEY
  #
  # update an SSL Endpoint on an app
  #
  def update
    fail("Usage: heroku certs:update PEM KEY\nMust specify PEM and KEY to update cert.") if args.size < 2
    pem = File.read(args[0]) rescue error("Unable to read #{args[0]} PEM")
    key = File.read(args[1]) rescue error("Unable to read #{args[1]} KEY")
    app = self.app
    cname = options[:endpoint] || current_endpoint

    endpoint = action("Updating SSL Endpoint #{cname} for #{app}") do
      heroku.ssl_endpoint_update(app, cname, pem, key)
    end

    display_warnings(endpoint)
    display "Updated certificate details:"
    display_certificate_info(endpoint)
  end

  # certs:rollback
  #
  # rollback an SSL Endpoint for an app
  #
  def rollback
    cname = options[:endpoint] || current_endpoint

    endpoint = action("Rolling back SSL Endpoint #{cname} for #{app}") do
      heroku.ssl_endpoint_rollback(app, cname)
    end

    display "New active certificate details:"
    display_certificate_info(endpoint)
  end

  private

  def current_endpoint
    endpoint = heroku.ssl_endpoint_list(app).first || error("#{app} has no SSL Endpoints.")
    endpoint["cname"]
  end

  def display_certificate_info(endpoint)
    data = {
      'Common Name(s)'  => endpoint['ssl_cert']['cert_domains'],
      'Expires At'      => format_date(endpoint['ssl_cert']['expires_at']),
      'Issuer'          => endpoint['ssl_cert']['issuer'],
      'Starts At'       => format_date(endpoint['ssl_cert']['starts_at']),
      'Subject'         => endpoint['ssl_cert']['subject']
    }
    styled_hash(data)

    if endpoint["ssl_cert"]["ca_signed?"]
      display "SSL certificate is verified by a root authority."
    elsif endpoint["issuer"] == endpoint["subject"]
      display "SSL certificate is self signed."
    else
      display "SSL certificate is not trusted."
    end
  end

  def display_warnings(endpoint)
    if endpoint["warnings"]
      endpoint["warnings"].each do |field, warning|
        display "WARNING: #{field} #{warning}"
      end
    end
  end

end
