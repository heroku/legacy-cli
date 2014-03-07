require 'heroku-api'
require "heroku/client"

class Heroku::Client::Organizations
  @headers = {}

  class << self

    def api options = {}
      @api ||= begin
        require("excon")
        key = Heroku::Auth.get_credentials[1]
        auth = "Basic #{Base64.encode64(':' + key).gsub("\n", '')}"
        hdrs = headers.merge( {"Authorization" => auth } )
        @connection = Excon.new(manager_url, options.merge(:headers => hdrs))
      end

      self
    end

    def add_headers(headers)
      @headers.merge! headers
    end

    def headers
      @headers
    end

    def request params
      begin
        response = @connection.request(params)
      rescue Excon::Errors::HTTPStatusError => error
        klass = case error.response.status
          when 401 then Heroku::API::Errors::Unauthorized
          when 402 then Heroku::API::Errors::VerificationRequired
          when 403 then Heroku::API::Errors::Forbidden
          when 404
            if error.request[:path].match /\/apps\/\/.*/
              Heroku::API::Errors::NilApp
            else
              Heroku::API::Errors::NotFound
            end
          when 408 then Heroku::API::Errors::Timeout
          when 422 then Heroku::API::Errors::RequestFailed
          when 423 then Heroku::API::Errors::Locked
          when 429 then Heroku::API::Errors::RateLimitExceeded
          when /50./ then Heroku::API::Errors::RequestFailed
          else Heroku::API::Errors::ErrorWithResponse
        end

        decompress_response!(error.response)
        reerror = klass.new(error.message, error.response)
        reerror.set_backtrace(error.backtrace)
        raise(reerror)
      end

      if response.body && !response.body.empty?
        decompress_response!(response)
        begin
          response.body = MultiJson.decode(response.body)
        rescue
          # leave non-JSON body as is
        end
      end

      # reset (non-persistent) connection
      # @connection.reset

      response
    end

    # Orgs
    #################################
    def get_orgs
      begin
        api.request(
          :expects => 200,
          :path => "/v1/user/info",
          :method => :get
        )

      # user is not a member of any organization
      rescue Heroku::API::Errors::NotFound
        Excon::Response.new(:body => { 'user' => {:not_found => true} })
      end
    end

    def remove_default_org
      api.request(
        :expects => 204,
        :method => :delete,
        :path => "/v1/user/default-organization"
      )
    end

    def set_default_org(org)
      api.request(
        :expects => 200,
        :method => :post,
        :path => "/v1/user/default-organization",
        :body => Heroku::Helpers.json_encode( { "default_organization" => org } ),
        :headers => {"Content-Type" => "application/json"}
      )
    end

    # Apps
    #################################
    def get_apps(org)
      api.request(
        :expects => 200,
        :method => :get,
        :path => "/v1/organization/#{org}/app"
      )
    end

    def post_app(params, org)
      params["app_name"] = params.delete("name") if params["name"]

      api.request(
        :expects => 201,
        :method => :post,
        :path => "/v1/organization/#{org}/create-app",
        :body => Heroku::Helpers.json_encode(params),
        :headers => {"Content-Type" => "application/json"}
      )
    end

    def transfer_app(to_org, app, locked)
      api.request(
        :expects => 200,
        :method => :put,
        :path => "/v1/app/#{app}",
        :body => Heroku::Helpers.json_encode( { "owner" => to_org, "locked" => locked || 'false' } ),
        :headers => {"Content-Type" => "application/json"}
      )
    end

    def post_collaborator(org, app, user)
      api.request(
        :expects => 200,
        :method => :post,
        :path => "v1/organization/#{org}/app/#{app}/collaborators",
        :body => Heroku::Helpers.json_encode({ "email" => user }),
        :headers => {"Content-Type" => "application/json"}
      )
    end

    def delete_collaborator(org, app, user)
      api.request(
        :expects => 200,
        :method => :delete,
        :path => "v1/organization/#{org}/app/#{app}/collaborators/#{user}"
      )
    end

    def join_app(app)
      api.request(
        :expects => 200,
        :method => :post,
        :path => "/v1/app/#{app}/join"
      )
    end

    def leave_app(app)
      api.request(
        :expects => 204,
        :method => :delete,
        :path => "/v1/app/#{app}/join"
      )
    end

    def lock_app(app)
      api.request(
        :expects => 200,
        :method => :post,
        :path => "/v1/app/#{app}/lock"
      )
    end

    def unlock_app(app)
      api.request(
        :expects => 204,
        :method => :delete,
        :path => "/v1/app/#{app}/lock"
      )
    end

    # Members
    #################################
    def get_members(org)
      api.request(
        :expects => 200,
        :method => :get,
        :path => "/v1/organization/#{org}/user"
      )
    end

    def add_member(org, member, role)
      api.request(
        :expects => [201, 302],
        :method => :post,
        :path => "/v1/organization/#{org}/user",
        :body => Heroku::Helpers.json_encode( { "email" => member, "role" => role } ),
        :headers => {"Content-Type" => "application/json"}
      )
    end

    def set_member(org, member, role)
      api.request(
        :expects => [200, 304],
        :method => :put,
        :path => "/v1/organization/#{org}/user/#{CGI.escape(member)}",
        :body => Heroku::Helpers.json_encode( { "role" => role } ),
        :headers => {"Content-Type" => "application/json"}
      )
    end

    def remove_member(org, member)
      api.request(
        :expects => 204,
        :method => :delete,
        :path => "/v1/organization/#{org}/user/#{CGI.escape(member)}"
      )
    end

    private

    def decompress_response!(response)
      return unless response.headers['Content-Encoding'] == 'gzip'
      response.body = Zlib::GzipReader.new(StringIO.new(response.body)).read
    end

    def manager_url
      ENV['HEROKU_MANAGER_URL'] || "https://manager-api.heroku.com"
    end

  end
end
