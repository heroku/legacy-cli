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

  end
end