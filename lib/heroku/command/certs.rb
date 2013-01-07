require "heroku/command/base"
require "excon"

# manage ssl endpoints for an app
#
class Heroku::Command::Certs < Heroku::Command::Base
  SSL_DOCTOR = Excon.new(ENV["SSL_DOCTOR_URL"] || "https://ssl-doctor.herokuapp.com/")

  class UsageError < StandardError; end

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

  # certs:chain PEM [PEM ...]
  #
  # Print the ordered and complete chain for the given certificate.
  #
  # Optional intermediate certificates may be given too, and will
  # be used during chain resolution.
  #
  def chain
    puts read_crt_through_ssl_doctor
  rescue UsageError
    fail("Usage: heroku certs:chain PEM [PEM ...]\nMust specify at least one certificate file.")
  end

  # certs:key PEM KEY [KEY ...]
  #
  # Print the correct key for the given certificate.
  #
  # You must pass one single certificate, and one or more keys.
  # The first key that signs the certificate will be printed back.
  #
  def key
    crt, key = read_crt_and_key_through_ssl_doctor("Testing for signing key")
    puts key
  rescue UsageError
    fail("Usage: heroku certs:key PEM KEY [KEY ...]\nMust specify one certificate file and at least one key file.")
  end

  # certs:add PEM KEY
  #
  # Add an ssl endpoint to an app.
  #
  #   --bypass  # bypass the trust chain completion step
  #
  def add
    crt, key = read_crt_and_key
    endpoint = action("Adding SSL Endpoint to #{app}") { heroku.ssl_endpoint_add(app, crt, key) }
    display_warnings(endpoint)
    display "#{app} now served by #{endpoint['cname']}"
    display "Certificate details:"
    display_certificate_info(endpoint)
  rescue UsageError
    fail("Usage: heroku certs:add PEM KEY\nMust specify PEM and KEY to add cert.")
  end

  # certs:update PEM KEY
  #
  # Update an SSL Endpoint on an app.
  #
  #   --bypass  # bypass the trust chain completion step
  #
  def update
    crt, key = read_crt_and_key
    cname    = options[:endpoint] || current_endpoint
    endpoint = action("Updating SSL Endpoint #{cname} for #{app}") { heroku.ssl_endpoint_update(app, cname, crt, key) }
    display_warnings(endpoint)
    display "Updated certificate details:"
    display_certificate_info(endpoint)
  rescue UsageError
    fail("Usage: heroku certs:update PEM KEY\nMust specify PEM and KEY to update cert.")
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

  def display(msg = "", new_line = true)
    super if $stdout.tty?
  end

  def post_to_ssl_doctor(path, action_text = nil)
    raise UsageError if args.size < 1
    action_text ||= "Resolving trust chain"
    action(action_text) do
      input = args.map { |arg| File.read(arg) rescue error("Unable to read #{args[0]} file") }.join("\n")
      SSL_DOCTOR.post(:path => path, :body => input, :headers => {'Content-Type' => 'application/octet-stream'}, :expects => 200).body
    end
  rescue Excon::Errors::BadRequest, Excon::Errors::UnprocessableEntity => e
    error(e.response.body)
  end

  def read_crt_and_key_through_ssl_doctor(action_text = nil)
    crt_and_key = post_to_ssl_doctor("resolve-chain-and-key", action_text)
    Heroku::OkJson.decode(crt_and_key).values_at("pem", "key")
  end

  def read_crt_through_ssl_doctor(action_text = nil)
    post_to_ssl_doctor("resolve-chain", action_text)
  end

  def read_crt_and_key_bypassing_ssl_doctor
    raise UsageError if args.size != 2
    crt = File.read(args[0]) rescue error("Unable to read #{args[0]} PEM")
    key = File.read(args[1]) rescue error("Unable to read #{args[1]} KEY")
    [crt, key]
  end

  def read_crt_and_key
    options[:bypass] ? read_crt_and_key_bypassing_ssl_doctor : read_crt_and_key_through_ssl_doctor
  end

end
