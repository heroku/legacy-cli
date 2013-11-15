require "heroku/client"

class Heroku::Client::Organizations
  class << self
    def api
      @api ||= begin
        require("excon")
        manager_url = ENV['HEROKU_MANAGER_URL'] || "https://manager-api.heroku.com"
        key = Heroku::Auth.get_credentials[1]
        auth = "Basic #{Base64.encode64(':' + key).gsub("\n", '')}"
        @headers = {} unless @headers
        hdrs = @headers.merge( {"Authorization" => auth } )
        Excon.new(manager_url, :headers => hdrs)
      end
    end

    def headers=(headers)
      @headers = headers
    end

    def get_orgs
      begin
        Heroku::Helpers.json_decode(api.request(
          :expects => 200,
          :path => "/v1/user/info",
          :method => :get
          ).body)
      rescue Excon::Errors::NotFound
        # user is not a member of any organization
        { 'user' => {} }
      end
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


    def get_members(org)
      Heroku::Helpers.json_decode(
        api.request(
          :expects => 200,
          :method => :get,
          :path => "/v1/organization/#{org}/user"
        ).body
      )
    end
  end
end