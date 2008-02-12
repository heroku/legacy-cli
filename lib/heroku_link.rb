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

	def upload_authkey(authkey)
		put("/users/1/authkey", authkey, { 'Content-Type' => 'text/ssh-authkey' })
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

	def xml(raw)
		REXML::Document.new(raw)
	end
end
