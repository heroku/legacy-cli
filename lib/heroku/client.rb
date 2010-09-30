require 'rexml/document'
require 'rest_client'
require 'uri'
require 'time'
require 'json/pure'

# A Ruby class to call the Heroku REST API.  You might use this if you want to
# manage your Heroku apps from within a Ruby program, such as Capistrano.
# 
# Example:
# 
#   require 'heroku'
#   heroku = Heroku::Client.new('me@example.com', 'mypass')
#   heroku.create('myapp')
#
class Heroku::Client
  def self.version
    '1.10.10'
  end

  def self.gem_version_string
    "heroku-gem/#{version}"
  end
  
  attr_reader :host, :user, :password

  def initialize(user, password, host='heroku.com')
    @user = user
    @password = password
    @host = host
  end

  # Show a list of apps which you are a collaborator on.
  def list
    doc = xml(get('/apps').to_s)
    doc.elements.to_a("//apps/app").map do |a|
      name = a.elements.to_a("name").first
      owner = a.elements.to_a("owner").first
      [name.text, owner.text]
    end
  end

  # Show info such as mode, custom domain, and collaborators on an app.
  def info(name_or_domain)
    name_or_domain = name_or_domain.gsub(/^(http:\/\/)?(www\.)?/, '')
    doc = xml(get("/apps/#{name_or_domain}").to_s)
    attrs = doc.elements.to_a('//app/*').inject({}) do |hash, element|
      hash[element.name.gsub(/-/, '_').to_sym] = element.text; hash
    end
    attrs.merge!(:collaborators => list_collaborators(attrs[:name]))
    attrs.merge!(:addons        => installed_addons(attrs[:name]))
  end

  # Create a new app, with an optional name.
  def create(name=nil, options={})
    name = create_request(name, options)
    loop do
      break if create_complete?(name)
      sleep 1
    end
    name
  end

  def create_request(name=nil, options={})
    options[:name] = name if name
    xml(post('/apps', :app => options).to_s).elements["//app/name"].text
  end

  def create_complete?(name)
    put("/apps/#{name}/status", {}).code == 201
  end

  # Update an app.  Available attributes:
  #   :name => rename the app (changes http and git urls)
  def update(name, attributes)
    put("/apps/#{name}", :app => attributes).to_s
  end

  # Destroy the app permanently.
  def destroy(name)
    delete("/apps/#{name}").to_s
  end

  # Get a list of collaborators on the app, returns an array of hashes each with :email
  def list_collaborators(app_name)
    doc = xml(get("/apps/#{app_name}/collaborators").to_s)
    doc.elements.to_a("//collaborators/collaborator").map do |a|
      { :email => a.elements['email'].text }
    end
  end

  # Invite a person by email address to collaborate on the app.
  def add_collaborator(app_name, email)
    xml(post("/apps/#{app_name}/collaborators", { 'collaborator[email]' => email }).to_s)
  rescue RestClient::RequestFailed => e
    raise e unless e.http_code == 422
    e.response.to_s
  end

  # Remove a collaborator.
  def remove_collaborator(app_name, email)
    delete("/apps/#{app_name}/collaborators/#{escape(email)}").to_s
  end

  def list_domains(app_name)
    doc = xml(get("/apps/#{app_name}/domains").to_s)
    doc.elements.to_a("//domain-names/*").map do |d|
      attrs = { :domain => d.elements['domain'].text }
      if cert = d.elements['cert']
        attrs[:cert] = {
          :expires_at => Time.parse(cert.elements['expires-at'].text),
          :subject    => cert.elements['subject'].text,
          :issuer     => cert.elements['issuer'].text,
        }
      end
      attrs
    end
  end

  def add_domain(app_name, domain)
    post("/apps/#{app_name}/domains", domain).to_s
  end

  def remove_domain(app_name, domain)
    delete("/apps/#{app_name}/domains/#{domain}").to_s
  end

  def remove_domains(app_name)
    delete("/apps/#{app_name}/domains").to_s
  end

  def add_ssl(app_name, pem, key)
    JSON.parse(post("/apps/#{app_name}/ssl", :pem => pem, :key => key).to_s)
  end

  def remove_ssl(app_name, domain)
    delete("/apps/#{app_name}/domains/#{domain}/ssl").to_s
  end

  def clear_ssl(app_name)
    delete("/apps/#{app_name}/ssl")
  end

  # Get the list of ssh public keys for the current user.
  def keys
    doc = xml get('/user/keys').to_s
    doc.elements.to_a('//keys/key').map do |key|
      key.elements['contents'].text
    end
  end

  # Add an ssh public key to the current user.
  def add_key(key)
    post("/user/keys", key, { 'Content-Type' => 'text/ssh-authkey' }).to_s
  end

  # Remove an existing ssh public key from the current user.
  def remove_key(key)
    delete("/user/keys/#{escape(key)}").to_s
  end

  # Clear all keys on the current user.
  def remove_all_keys
    delete("/user/keys").to_s
  end

  # Get a list of stacks available to the app, with the current one marked.
  def list_stacks(app_name)
    JSON.parse resource("/apps/#{app_name}/stack").get(:accept => 'application/json').to_s
  end

  # Request a stack migration.
  def migrate_to_stack(app_name, stack)
    resource("/apps/#{app_name}/stack").put(stack, :accept => 'text/plain').to_s
  end

  class AppCrashed < RuntimeError; end

  # Run a rake command on the Heroku app and return all output as
  # a string.
  def rake(app_name, cmd)
    start(app_name, "rake #{cmd}", attached=true).to_s
  end

  # support for console sessions
  class ConsoleSession
    def initialize(id, app, client)
      @id = id; @app = app; @client = client
    end
    def run(cmd)
      @client.run_console_command("/apps/#{@app}/consoles/#{@id}/command", cmd, "=> ")
    end
  end

  # Execute a one-off console command, or start a new console tty session if
  # cmd is nil.
  def console(app_name, cmd=nil)
    if block_given?
      id = post("/apps/#{app_name}/consoles").to_s
      yield ConsoleSession.new(id, app_name, self)
      delete("/apps/#{app_name}/consoles/#{id}").to_s
    else
      run_console_command("/apps/#{app_name}/console", cmd)
    end
  rescue RestClient::BadGateway => e
    raise(AppCrashed, e.response.to_s)
  end

  # internal method to run console commands formatting the output
  def run_console_command(url, command, prefix=nil)
    output = post(url, command).to_s
    return output unless prefix
    if output.include?("\n")
      lines  = output.split("\n")
      (lines[0..-2] << "#{prefix}#{lines.last}").join("\n")
    else
      prefix + output
    end
  rescue RestClient::RequestFailed => e
    if Heroku::Command.parse_error_xml(e.http_body)
      Heroku::Command.extract_error(e.http_body)
    elsif e.http_code == 422
      e.http_body
    else
      raise e
    end
  end

  class Service
    attr_accessor :attached, :upid

    def initialize(client, app, upid=nil)
      @client = client
      @app = app
      @upid = upid
    end

    # start the service
    def start(command, attached=false)
      @attached = attached
      @response = @client.post(
        "/apps/#{@app}/services",
        command,
        :content_type => 'text/plain'
      )
      @next_chunk = @response.to_s
      @interval = 0
      self
    rescue RestClient::RequestFailed => e
      raise AppCrashed, e.http_body  if e.http_code == 502
      raise
    end

    def transition(action)
      @response = @client.put(
        "/apps/#{@app}/services/#{@upid}",
        action,
        :content_type => 'text/plain'
      ).to_s
      self
    rescue RestClient::RequestFailed => e
      raise AppCrashed, e.http_body  if e.http_code == 502
      raise
    end

    def down   ; transition('down') ; end
    def up     ; transition('up')   ; end
    def bounce ; transition('bounce') ; end

    # Does the service have any remaining output?
    def end_of_stream?
      @next_chunk.nil?
    end

    # Read the next chunk of output.
    def read
      chunk = @client.get(@next_chunk)
      if chunk.headers[:location].nil? && chunk.code != 204
        # no more chunks
        @next_chunk = nil
        chunk.to_s
      elsif chunk.to_s == ''
        # assume no content and back off
        @interval = 2
        ''
      elsif location = chunk.headers[:location]
        # some data read and next chunk available
        @next_chunk = location
        @interval = 0
        chunk.to_s
      end
    end

    # Iterate over all output chunks until EOF is reached.
    def each
      until end_of_stream?
        sleep(@interval)
        output = read
        yield output unless output.empty?
      end
    end

    # All output as a string
    def to_s
      buf = []
      each { |part| buf << part }
      buf.join
    end
  end

  # Retreive ps list for the given app name.
  def ps(app_name)
    JSON.parse resource("/apps/#{app_name}/ps").get(:accept => 'application/json').to_s
  end

  # Run a service. If Responds to #each and yields output as it's received.
  def start(app_name, command, attached=false)
    service = Service.new(self, app_name)
    service.start(command, attached)
  end

  # Get a Service instance to execute commands against.
  def service(app_name, upid)
    Service.new(self, app_name, upid)
  end

  # Bring a service up.
  def up(app_name, upid)
    service(app_name, upid).up
  end

  # Bring a service down.
  def down(app_name, upid)
    service(app_name, upid).down
  end

  # Bounce a service.
  def bounce(app_name, upid)
    service(app_name, upid).bounce
  end


  # Restart the app servers.
  def restart(app_name)
    delete("/apps/#{app_name}/server").to_s
  end

  # Fetch recent logs from the app server.
  def logs(app_name)
    get("/apps/#{app_name}/logs").to_s
  end

  # Fetch recent cron logs from the app server.
  def cron_logs(app_name)
    get("/apps/#{app_name}/cron_logs").to_s
  end

  # Scales the web processes.
  def set_dynos(app_name, qty)
    put("/apps/#{app_name}/dynos", :dynos => qty).to_s
  end

  # Scales the background processes.
  def set_workers(app_name, qty)
    put("/apps/#{app_name}/workers", :workers => qty).to_s
  end

  # Capture a bundle from the given app, as a backup or for download.
  def bundle_capture(app_name, bundle_name=nil)
    xml(post("/apps/#{app_name}/bundles", :bundle => { :name => bundle_name }).to_s).elements["//bundle/name"].text
  end

  def bundle_destroy(app_name, bundle_name)
    delete("/apps/#{app_name}/bundles/#{bundle_name}").to_s
  end

  # Get a temporary URL where the bundle can be downloaded.
  # If bundle_name is nil it will use the most recently captured bundle for the app
  def bundle_url(app_name, bundle_name=nil)
    bundle = JSON.parse(get("/apps/#{app_name}/bundles/#{bundle_name || 'latest'}", { :accept => 'application/json' }).to_s)
    bundle['temporary_url']
  end

  def bundle_download(app_name, fname, bundle_name=nil)
    warn "[DEPRECATION] `bundle_download` is deprecated. Please use `bundle_url` instead"
    data = RestClient.get(bundle_url(app_name, bundle_name)).to_s
    File.open(fname, "wb") { |f| f.write data }
  end

  # Get a list of bundles of the app.
  def bundles(app_name)
    doc = xml(get("/apps/#{app_name}/bundles").to_s)
    doc.elements.to_a("//bundles/bundle").map do |a|
      {
        :name => a.elements['name'].text,
        :state => a.elements['state'].text,
        :created_at => Time.parse(a.elements['created-at'].text),
      }
    end
  end

  def config_vars(app_name)
    JSON.parse get("/apps/#{app_name}/config_vars").to_s
  end

  def add_config_vars(app_name, new_vars)
    put("/apps/#{app_name}/config_vars", new_vars.to_json).to_s
  end

  def remove_config_var(app_name, key)
    delete("/apps/#{app_name}/config_vars/#{key}").to_s
  end

  def clear_config_vars(app_name)
    delete("/apps/#{app_name}/config_vars").to_s
  end

  def addons
    JSON.parse get("/addons", :accept => 'application/json').to_s
  end

  def installed_addons(app_name)
    JSON.parse get("/apps/#{app_name}/addons", :accept => 'application/json').to_s
  end

  def install_addon(app_name, addon, config={})
    post("/apps/#{app_name}/addons/#{escape(addon)}", { :config => config }, :accept => 'application/json').to_s
  end

  def uninstall_addon(app_name, addon)
    delete("/apps/#{app_name}/addons/#{escape(addon)}", :accept => 'application/json').to_s
  end

  def confirm_billing
    post("/user/#{escape(@user)}/confirm_billing").to_s
  end

  def on_warning(&blk)
    @warning_callback = blk
  end

  ##################

  def resource(uri)
    RestClient.proxy = ENV['HTTP_PROXY'] || ENV['http_proxy']
    if uri =~ /^https?/
      RestClient::Resource.new(uri, user, password)
    else
      RestClient::Resource.new("https://api.#{host}", user, password)[uri]
    end
  end

  def get(uri, extra_headers={})    # :nodoc:
    process(:get, uri, extra_headers)
  end

  def post(uri, payload="", extra_headers={})    # :nodoc:
    process(:post, uri, extra_headers, payload)
  end

  def put(uri, payload, extra_headers={})    # :nodoc:
    process(:put, uri, extra_headers, payload)
  end

  def delete(uri, extra_headers={})    # :nodoc:
    process(:delete, uri, extra_headers)
  end

  def process(method, uri, extra_headers={}, payload=nil)
    headers  = heroku_headers.merge(extra_headers)
    args     = [method, payload, headers].compact
    response = resource(uri).send(*args)

    extract_warning(response)
    response
  end

  def extract_warning(response)
    return unless response
    if response.headers[:x_heroku_warning] && @warning_callback
      warning = response.headers[:x_heroku_warning]
      @displayed_warnings ||= {}
      unless @displayed_warnings[warning]
        @warning_callback.call(warning)
        @displayed_warnings[warning] = true
      end
    end
  end

  def heroku_headers   # :nodoc:
    {
      'X-Heroku-API-Version' => '2',
      'User-Agent'           => self.class.gem_version_string,
      'X-Ruby-Version'       => RUBY_VERSION,
      'X-Ruby-Platform'      => RUBY_PLATFORM
    }
  end

  def xml(raw)   # :nodoc:
    REXML::Document.new(raw)
  end

  def escape(value)  # :nodoc:
    escaped = URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    escaped.gsub('.', '%2E') # not covered by the previous URI.escape
  end

  def database_session(app_name)
    JSON.parse(post("/apps/#{app_name}/database/session2", '', :x_taps_version => ::Taps.version).to_s)
  end

  def database_reset(app_name)
    post("/apps/#{app_name}/database/reset", '').to_s
  end

  def maintenance(app_name, mode)
    mode = mode == :on ? '1' : '0'
    post("/apps/#{app_name}/server/maintenance", :maintenance_mode => mode).to_s
  end

	def httpcache_purge(app_name)
		delete("/apps/#{app_name}/httpcache").to_s
	end
end
