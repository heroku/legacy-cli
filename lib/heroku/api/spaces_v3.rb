module Heroku
  class API
    def get_space_v3(space_identity)
      request(
        :method => :get,
        :expects => [200],
        :path => "/spaces/#{space_identity}",
        :headers => {
          "Accept" => "application/vnd.heroku+json; version=3"
        }
      )
    end
  end
end
