module Heroku
  class API
    def post_organizations_app_v3(params={})
      request(
        :method => :post,
        :body => Heroku::Helpers.json_encode(params),
        :expects => 201,
        :path => "/organizations/apps",
        :headers => {
          "Accept" => "application/vnd.heroku+json; version=3"
        }
      )
    end
  end
end
