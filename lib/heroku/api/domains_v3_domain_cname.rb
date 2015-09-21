module Heroku
  class API
    # TODO: rename methods and filename after 3.domain-cname is merged

    def get_domains_v3_domain_cname(app, range=nil)
      rsp = request(
        :expects => [200, 206],
        :method  => :get,
        :path    => "/apps/#{app}/domains",
        :headers => {
          "Accept" => "application/vnd.heroku+json; version=3.domain-cname",
          "Range"  => range
        }
      )
      if rsp.headers['Next-Range']
        rsp.body + get_domains_v3_domain_cname(app, rsp.headers['Next-Range'])
      else
        rsp.body
      end
    end

    def post_domains_v3_domain_cname(app, hostname)
      request(
        :expects => 201,
        :method  => :post,
        :path    => "/apps/#{app}/domains",
        :headers => {
          "Accept" => "application/vnd.heroku+json; version=3.domain-cname",
          "Content-Type" => "application/json"
        },
        body: Heroku::Helpers.json_encode({'hostname' => hostname})
      )
    end
  end
end
