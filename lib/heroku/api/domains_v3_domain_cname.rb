module Heroku
  class API
    # TODO: rename methods and filename after 3.domain-cname is merged

    def get_domains_v3_domain_cname(app)
      request(
        :expects => 200,
        :method  => :get,
        :path    => "/apps/#{app}/domains",
        :headers => {
          "Accept" => "application/vnd.heroku+json; version=3.domain-cname"
        }
      )
    end
  end
end
