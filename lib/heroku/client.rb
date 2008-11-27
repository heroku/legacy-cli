require 'rubygems'
require 'rexml/document'
require 'rest_client'
require 'uri'
require 'time'

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
	attr_reader :host, :user, :password

	def initialize(user, password, host='heroku.com')
		@user = user
		@password = password
		@host = host
	end

	# Show a list of apps which you are a collaborator on.
	def list
		doc = xml(get('/apps'))
		doc.elements.to_a("//apps/app/name").map { |a| a.text }
	end

	# Show info such as mode, custom domain, and collaborators on an app.
	def info(name_or_domain)
		name_or_domain = name_or_domain.gsub(/^(http:\/\/)?(www\.)?/, '')
		doc = xml(get("/apps/#{name_or_domain}"))
		attrs = doc.elements.to_a('//app/*').inject({}) do |hash, element|
			hash[element.name.gsub(/-/, '_').to_sym] = element.text; hash
		end
		attrs.merge(:collaborators => list_collaborators(attrs[:name]))
	end

	# Create a new app, with an optional name.
	def create(name=nil, options={})
		options[:name] = name if name
		xml(post('/apps', :app => options)).elements["//app/name"].text
	end

	# Update an app.  Available attributes:
	#   :name => rename the app (changes http and git urls)
	def update(name, attributes)
		put("/apps/#{name}", :app => attributes)
	end

	# Destroy the app permanently.
	def destroy(name)
		delete("/apps/#{name}")
	end

	# Get a list of collaborators on the app, returns an array of hashes each of
	# which contain :email and :access (=> edit | view) elements.
	def list_collaborators(app_name)
		doc = xml(get("/apps/#{app_name}/collaborators"))
		doc.elements.to_a("//collaborators/collaborator").map do |a|
			{ :email => a.elements['email'].text, :access => a.elements['access'].text }
		end
	end

	# Invite a person by email address to collaborate on the app.
	def add_collaborator(app_name, email)
		xml(post("/apps/#{app_name}/collaborators", { 'collaborator[email]' => email }))
	end

	# Change an existing collaborator.
	def update_collaborator(app_name, email, access)
		put("/apps/#{app_name}/collaborators/#{escape(email)}", { 'collaborator[access]' => access })
	end

	# Remove a collaborator.
	def remove_collaborator(app_name, email)
		delete("/apps/#{app_name}/collaborators/#{escape(email)}")
	end

	def list_domains(app_name)
		doc = xml(get("/apps/#{app_name}/domains"))
		doc.elements.to_a("//domain-names/domain-name").map do |d|
			d.elements['domain'].text
		end
	end

	def add_domain(app_name, domain)
		post("/apps/#{app_name}/domains", domain)
	end

	def remove_domain(app_name, domain)
		delete("/apps/#{app_name}/domains/#{domain}")
	end

	def remove_domains(app_name)
		delete("/apps/#{app_name}/domains")
	end

	# Get the list of ssh public keys for the current user.
	def keys
		doc = xml get('/user/keys')
		doc.elements.to_a('//keys/key').map do |key|
			key.elements['contents'].text
		end
	end

	# Add an ssh public key to the current user.
	def add_key(key)
		post("/user/keys", key, { 'Content-Type' => 'text/ssh-authkey' })
	end

	# Remove an existing ssh public key from the current user.
	def remove_key(key)
		delete("/user/keys/#{escape(key)}")
	end

	# Clear all keys on the current user.
	def remove_all_keys
		delete("/user/keys")
	end

	# Run a rake command on the Heroku app.
	def rake(app_name, cmd)
		post("/apps/#{app_name}/rake", cmd)
	end

	# support for console sessions
	class ConsoleSession
		def initialize(id, app, client)
			@id = id; @app = app; @client = client
		end
		def run(cmd)
			@client.post("/apps/#{@app}/consoles/#{@id}/command", :command => cmd)
		end
	end

	# Execute a one-off console command, or start a new console tty session if
	# cmd is nil.
	def console(app_name, cmd=nil)
		if block_given?
			id = post("/apps/#{app_name}/consoles")
			yield ConsoleSession.new(id, app_name, self)
			delete("/apps/#{app_name}/consoles/#{id}")
		else
			post("/apps/#{app_name}/console", cmd)
		end
	end

	# Restart the app servers.
	def restart(app_name)
		delete("/apps/#{app_name}/server")
	end

	# Fetch recent logs from the app server.
	def logs(app_name)
		get("/apps/#{app_name}/logs")
	end

	# Fetch recent cron logs from the app server.
	def cron_logs(app_name)
		get("/apps/#{app_name}/cron_logs")
	end

	# Capture a bundle from the given app, as a backup or for download.
	def bundle_capture(app_name, bundle_name=nil)
		xml(post("/apps/#{app_name}/bundles", :bundle => { :name => bundle_name })).elements["//bundle/name"].text
	end

	def bundle_destroy(app_name, bundle_name)
		delete("/apps/#{app_name}/bundles/#{bundle_name}")
	end

	# Download a previously captured bundle.  If bundle_name is nil, the most
	# recently captured bundle for that app will be downloaded.
	def bundle_download(app_name, fname, bundle_name=nil)
		data = get("/apps/#{app_name}/bundles/#{bundle_name || 'latest'}")
		File.open(fname, "w") { |f| f.write data }
	end

	# Get a list of bundles of the app.
	def bundles(app_name)
		doc = xml(get("/apps/#{app_name}/bundles"))
		doc.elements.to_a("//bundles/bundle").map do |a|
			{
				:name => a.elements['name'].text,
				:state => a.elements['state'].text,
				:created_at => Time.parse(a.elements['created-at'].text),
			}
		end
	end

	##################

	def resource(uri)
		RestClient::Resource.new("http://#{host}", user, password)[uri]
	end

	def get(uri, extra_headers={})    # :nodoc:
		resource(uri).get(heroku_headers.merge(extra_headers))
	end

	def post(uri, payload="", extra_headers={})    # :nodoc:
		resource(uri).post(payload, heroku_headers.merge(extra_headers))
	end

	def put(uri, payload, extra_headers={})    # :nodoc:
		resource(uri).put(payload, heroku_headers.merge(extra_headers))
	end

	def delete(uri)    # :nodoc:
		resource(uri).delete
	end

	def heroku_headers   # :nodoc:
		{ 'X-Heroku-API-Version' => '1' }
	end

	def xml(raw)   # :nodoc:
		REXML::Document.new(raw)
	end

	def escape(value)  # :nodoc:
		escaped = URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
		escaped.gsub('.', '%2E') # not covered by the previous URI.escape
	end
end
