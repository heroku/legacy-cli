module Heroku
  class API
    def get_space(space_identity)
      request(
        :method => :get,
        :expects => [200],
        :path => "/spaces/#{space_identity}",
        :headers => {
          "Accept" => "application/vnd.heroku+json"
        }
      )
    end
  end
end
