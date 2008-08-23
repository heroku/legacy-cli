require 'rubygems'
require 'rexml/document'
require 'rest_client'
require 'uri'

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

	def list
		doc = xml(get('/apps'))
		doc.elements.to_a("//apps/app/name").map { |a| a.text }
	end

	def info(name)
		doc = xml(get("/apps/#{name}"))
		attrs = { :collaborators => list_collaborators(name) }
		doc.elements.to_a('//app/*').inject(attrs) do |hash, element|
			hash[element.name.to_sym] = element.text; hash
		end
	end

	def create(name=nil, options={})
		params = {}
		params['app[name]'] = name if name
		params['app[origin]'] = options[:origin] if options[:origin]
		xml(post('/apps', params)).elements["//app/name"].text
	end

	def update(name, attributes)
		uri = "/apps/#{name}"
		# rest-client doesn't support nested payloads yet at least
		payload = {}
		attributes.each { |k, v| payload["app[#{k}]"] = v }
		put(uri, payload)
	end

	def destroy(name)
		delete("/apps/#{name}")
	end

	# collaborators
	def list_collaborators(app_name)
		doc = xml(get("/apps/#{app_name}/collaborators"))
		doc.elements.to_a("//collaborators/collaborator").map do |a|
			{ :email => a.elements['email'].text, :access => a.elements['access'].text }
		end
	end

	def add_collaborator(app_name, email, access='view')
		xml(post("/apps/#{app_name}/collaborators", { 'collaborator[email]' => email, 'collaborator[access]' => access }))
	end

	def update_collaborator(app_name, email, access)
		put("/apps/#{app_name}/collaborators/#{escape(email)}", { 'collaborator[access]' => access })
	end

	def remove_collaborator(app_name, email)
		delete("/apps/#{app_name}/collaborators/#{escape(email)}")
	end

	def keys
		doc = xml get('/user/keys')
		doc.elements.to_a('//authkeys/authkey').map do |key|
			key.elements['contents'].text
		end
	end

	def add_key(key)
		post("/user/keys", key, { 'Content-Type' => 'text/ssh-authkey' })
	end

	def remove_key(key)
		delete("/user/keys/#{key}")
	end

	def remove_all_keys
		delete("/user/keys/")
	end

	def upload_authkey(key)
		put("/user/authkey", key, { 'Content-Type' => 'text/ssh-authkey' })
	end

	def db_import(app_name, file)
		control_resource(app_name)['data'].put File.read(file), :content_type => 'text/plain'
	end

	def db_export(app_name, file)
		File.open(file, 'w') do |f|
			f.write get("/apps/#{app_name}/data")
		end
	end

	def rake(app_name, cmd)
		post("/apps/#{app_name}/rake", cmd)
	end

	##################

	def resource(uri)
		RestClient::Resource.new(host + uri, user, password)
	end

	def control_resource(app_name)
		RestClient::Resource.new("http://control.#{app_name}.#{host}", user, password)
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

	def escape(value)
		escaped = URI.escape(value.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
		escaped.gsub('.', '%2E') # not covered by the previous URI.escape
	end
end
