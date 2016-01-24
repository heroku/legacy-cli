module Heroku
  class API
    def get_regions_v3
      request(
        :method => :get,
        :expects => [200],
        :path => "/regions",
        :headers => {
          "Accept" => "application/vnd.heroku+json; version=3"
        }
      )
    end
  end
end
