require 'net/http'
require 'yaml'
require 'rexml/document'
require 'fileutils'

class HerokuLink
	attr_reader :host, :user, :password

	def initialize(host, user, password)
		@host = host
		@user = user
		@password = password
	end

	def list
		doc = xml(get('/apps'))
		doc.elements.to_a("//apps/app/name").map { |a| a.text }
	end

	def create(name=nil)
		uri = "/apps"
		uri += "?app[name]=#{name}" if name
		xml(post(uri)).elements["//app/name"].text
	end

	def destroy(name)
		delete("/apps/#{name}")
	end

	def import(name, archive)
		put("/apps/#{name}", archive, { 'Content-Type' => 'application/x-gtar' })
	end

	def export(name)
		get("/apps/#{name}", { 'Accept' => 'application/x-gtar' })
	end

	##################

	def get(uri, extra_headers={})
		transmit Net::HTTP::Get.new(uri, headers.merge(extra_headers))
	end

	def post(uri, payload="")
		transmit Net::HTTP::Post.new(uri, headers), payload
	end

	def put(uri, payload, extra_headers={})
		transmit Net::HTTP::Put.new(uri, headers.merge(extra_headers)), payload
	end

	def delete(uri)
		transmit Net::HTTP::Delete.new(uri, headers)
	end

	def transmit(req, payload=nil)
		req.basic_auth user, password
		Net::HTTP.start(host) do |http|
			res = http.request(req, payload)
			unless %w(200 201 202).include? res.code
				raise "HTTP transmit failed, code: #{res.code}"
			else
				res.body
			end
		end
	end

	def headers
		{ 'Accept' => 'application/xml' }
	end

	def user
		@credentials ||= credentials
		@credentials[0]
	end

	def password
		@credentials ||= credentials
		@credentials[1]
	end

	def credentials_file
		"#{ENV['HOME']}/.heroku/credentials"
	end

	def credentials
		if File.exists? credentials_file
			File.read(credentials_file).split("\n")
		else
			ask_for_credentials
		end
	end

	def ask_for_credentials
		print "User: "
		user = gets.strip
		print "Password: "
		password = gets.strip

		save_credentials user, password

		upload_authkey

		[ user, password ]
	end

	def save_credentials(user, password)
		FileUtils.mkdir_p(File.dirname(credentials_file))
		File.open(credentials_file, 'w') do |f|
			f.puts user
			f.puts password
		end
	end

	def upload_authkey
		puts "Uploading ssh public key"
		put("/user/authkey", authkey, { 'Content-Type' => 'text/ssh-authkey' })
	end

	def authkey
		File.read("#{ENV['HOME']}/.ssh/id_rsa.pub")
	end

	def xml(raw)
		REXML::Document.new(raw)
	end
end
