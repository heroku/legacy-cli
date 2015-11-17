module Heroku
  class API
    def post_organizations_app(params={})
      request(
        :method => :post,
        :body => Heroku::Helpers.json_encode(params),
        :expects => 201,
        :path => "/organizations/apps",
        :headers => {
          "Accept" => "application/vnd.heroku+json"
        }
      )
    end
  end
end
