require "heroku/command/base"
require "heroku/open_ssl"
require "excon"

# manage ssl endpoints for an app
#
class Heroku::Command::Certs < Heroku::Command::Base
  SSL_DOCTOR = Excon.new(ENV["SSL_DOCTOR_URL"] || "https://ssl-doctor.herokuapp.com/")

  class UsageError < StandardError; end

  # certs
  #
  # List ssl endpoints for an app.
  #
  def index
    endpoints = heroku.ssl_endpoint_list(app)

    if endpoints.empty?
      display "#{app} has no SSL Endpoints."
      display "Use `heroku certs:add CRT KEY` to add one."
    else
      endpoints.map! do |endpoint|
        ssl_cert_attributes = {}
        if cert = endpoint['ssl_cert']
          ssl_cert_attributes.merge!(
            'domains'    => cert['cert_domains'].join(', '),
            'expires_at' => format_date(cert['expires_at']),
            'ca_signed?' => cert['ca_signed?'].to_s.capitalize)
        end
        { 'cname' => endpoint['cname'] }.merge(ssl_cert_attributes)
      end
      display_table(
        endpoints,
        %w( cname domains expires_at ca_signed? ),
        [ "Endpoint", "Common Name(s)", "Expires", "Trusted" ]
      )
    end
  end

  # certs:chain CRT [CRT ...]
  #
  # Print the ordered and complete chain for the given certificate.
  #
  # Optional intermediate certificates may be given too, and will
  # be used during chain resolution.
  #
  def chain
    puts read_crt_through_ssl_doctor
  rescue UsageError
    fail("Usage: heroku certs:chain CRT [CRT ...]\nMust specify at least one certificate file.")
  end

  # certs:key CRT KEY [KEY ...]
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
    fail("Usage: heroku certs:key CRT KEY [KEY ...]\nMust specify one certificate file and at least one key file.")
  end

  # certs:add CRT KEY
  #
  # Add an ssl endpoint to an app.
  #
  #   --bypass                 # bypass the trust chain completion step
  #
  def add
    crt, key = read_crt_and_key
    endpoint = action("Adding SSL Endpoint to #{app}") { heroku.ssl_endpoint_add(app, crt, key) }
    display_warnings(endpoint)
    display "#{app} now served by #{endpoint['cname']}"
    display "Certificate details:"
    display_certificate_info(endpoint)
  rescue UsageError
    fail("Usage: heroku certs:add CRT KEY\nMust specify CRT and KEY to add cert.")
  end

  # certs:update CRT KEY
  #
  # Update an SSL Endpoint on an app.
  #
  #   --bypass                 # bypass the trust chain completion step
  #   -e, --endpoint ENDPOINT  # name of the endpoint to update
  #
  def update
    crt, key = read_crt_and_key
    cname    = options[:endpoint] || current_endpoint
    message = "WARNING: Potentially Destructive Action\nThis command will change the certificate of endpoint #{cname} on #{app}."
    return unless confirm_command(app, message)
    endpoint = action("Updating SSL Endpoint #{cname} for #{app}") { heroku.ssl_endpoint_update(app, cname, crt, key) }
    display_warnings(endpoint)
    display "Updated certificate details:"
    display_certificate_info(endpoint)
  rescue UsageError
    fail("Usage: heroku certs:update CRT KEY\nMust specify CRT and KEY to update cert.")
  end

  # certs:info
  #
  # Show certificate information for an ssl endpoint.
  #
  #   -e, --endpoint ENDPOINT  # name of the endpoint to check info on
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
  # Remove an SSL Endpoint from an app.
  #
  #   -e, --endpoint ENDPOINT  # name of the endpoint to remove
  #
  def remove
    cname = options[:endpoint] || current_endpoint
    message = "WARNING: Potentially Destructive Action\nThis command will remove the endpoint #{cname} from #{app}."
    return unless confirm_command(app, message)
    action("Removing SSL Endpoint #{cname} from #{app}") do
      heroku.ssl_endpoint_remove(app, cname)
    end
    display "NOTE: Billing is still active. Remove SSL Endpoint add-on to stop billing."
  end

  # certs:rollback
  #
  # Rollback an SSL Endpoint for an app.
  #
  #   -e, --endpoint ENDPOINT  # name of the endpoint to rollback
  #
  def rollback
    cname = options[:endpoint] || current_endpoint

    message = "WARNING: Potentially Destructive Action\nThis command will rollback the certificate of endpoint #{cname} on #{app}."
    return unless confirm_command(app, message)

    endpoint = action("Rolling back SSL Endpoint #{cname} for #{app}") do
      heroku.ssl_endpoint_rollback(app, cname)
    end

    display "New active certificate details:"
    display_certificate_info(endpoint)
  end
  
  # certs:generate DOMAIN
  # 
  # Generate a key and certificate signing request (or self-signed certificate) 
  # for an app. Prompts for information to put in the certificate unless --now 
  # is used, or at least one of the --subject, --owner, --country, --area, or 
  # --city options is specified.
  # 
  #   --selfsigned              # generate a self-signed certificate instead of a CSR
  #   --keysize BITSIZE         # RSA key size in bits (default: 2048)
  #   --owner NAME              # name of organization certificate belongs to
  #   --country COUNTRY         # country of owner, as a two-letter ISO country code
  #   --area AREA               # sub-country area (state, province, etc.) of owner
  #   --city CITY               # city of owner
  #   --subject SUBJECT         # specify entire certificate subject
  #   --now                     # do not prompt for any owner information
  def generate
    request = Heroku::OpenSSL::CertificateRequest.new
    
    request.domain = args[0] || error("certs:generate must specify a domain")
    request.subject = cert_subject_for_domain_and_options(request.domain, options)
    request.self_signed = options[:selfsigned] || false
    request.key_size = (options[:keysize] || request.key_size).to_i
    
    result = request.generate
    
    explain_step_after_generate result
        
  rescue Heroku::OpenSSL::NotInstalledError => ex
    error("The OpenSSL command-line tools must be installed to use certs:generate.\n" + ex.installation_hint)
    
  rescue Heroku::OpenSSL::GenericError => ex
    error(ex.message)
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
      input = args.map { |arg|
        begin
          certbody=File.read(arg)
        rescue => e
          error("Unable to read #{arg} file: #{e}") 
        end
        certbody
      }.join("\n")
      SSL_DOCTOR.post(:path => path, :body => input, :headers => {'Content-Type' => 'application/octet-stream'}, :expects => 200).body
    end

  rescue Excon::Errors::BadRequest, Excon::Errors::UnprocessableEntity => e
    error(e.response.body)
  end

  def read_crt_and_key_through_ssl_doctor(action_text = nil)
    crt_and_key = post_to_ssl_doctor("resolve-chain-and-key", action_text)
    MultiJson.load(crt_and_key).values_at("pem", "key")
  end

  def read_crt_through_ssl_doctor(action_text = nil)
    post_to_ssl_doctor("resolve-chain", action_text)
  end

  def read_crt_and_key_bypassing_ssl_doctor
    raise UsageError if args.size != 2
    crt = File.read(args[0]) rescue error("Unable to read #{args[0]} CRT")
    key = File.read(args[1]) rescue error("Unable to read #{args[1]} KEY")
    [crt, key]
  end

  def read_crt_and_key
    options[:bypass] ? read_crt_and_key_bypassing_ssl_doctor : read_crt_and_key_through_ssl_doctor
  end
  
  def all_endpoint_domains
    endpoints = heroku.ssl_endpoint_list(app)
    endpoints.select { |endpoint| endpoint['ssl_cert'] && endpoint['ssl_cert']['cert_domains'] } \
              .map   { |endpoint| endpoint['ssl_cert']['cert_domains'] } \
              .reduce(:+)
  end
  
  def prompt(question)
    display("#{question}: ", false)
    ask
  end
  
  def val_empty?(val)
    val.nil? or val.empty?
  end
  
  def cert_subject_for_domain_and_options(domain, options = {})
    raise ArgumentError, "domain cannot be empty" if domain.nil? || domain.empty?
    
    subject, country, area, city, owner, now = options.values_at(:subject, :country, :area, :city, :owner, :now)
    
    if val_empty? subject
      if !now && [country, area, city, owner].all? { |v| val_empty? v }
        owner = prompt "Owner of this certificate"
        country = prompt "Country of owner (two-letter ISO code)"
        area = prompt "State/province/etc. of owner"
        city = prompt "City of owner"
      end
    
      subject = ""
      subject += "/C=#{country}" unless val_empty? country
      subject += "/ST=#{area}" unless val_empty? area
      subject += "/L=#{city}" unless val_empty? city
      subject += "/O=#{owner}" unless val_empty? owner
      
      subject += "/CN=#{domain}"
    end
    
    subject
  end
  
  def explain_step_after_generate(result)
    if result.csr_file.nil?
      display "Your key and self-signed certificate have been generated."
      display "Next, run:"
    else
      display "Your key and certificate signing request have been generated."
      display "Submit the CSR in '#{result.csr_file}' to your preferred certificate authority."
      display "When you've received your certificate, run:"
    end
    
    needs_addon = false
    command = "add"
    begin
      command = "update" if all_endpoint_domains.include? result.request.domain
    rescue RestClient::Forbidden
      needs_addon = true
    end
    
    display "$ heroku addons:add ssl:endpoint" if needs_addon
    display "$ heroku certs:#{command} #{result.crt_file || "CERTFILE"} #{result.key_file}"
  end
end
