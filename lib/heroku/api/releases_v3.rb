module Heroku
  class API
    def get_releases_v3(app, range=nil)
      headers = { 'Accept' => 'application/vnd.heroku+json; version=3' }
      headers.merge!('Range' => range) if range
      request(
        :expects  => [ 200, 206 ],
        :headers  => headers,
        :method   => :get,
        :path     => "/apps/#{app}/releases"
      )
    end

    def post_release_v3(app, slug_id, opts={})
      headers = {
        'Accept'       => 'application/vnd.heroku+json; version=3',
        'Content-Type' => 'application/json'
      }
      headers.merge!('Heroku-Deploy-Type' => opts[:deploy_type]) if opts[:deploy_type]
      headers.merge!('Heroku-Deploy-Source' => opts[:deploy_source]) if opts[:deploy_source]

      body = { 'slug' => slug_id }
      body.merge!('description' => opts[:description]) if opts[:description]

      request(
        :expects  => 201,
        :headers  => headers,
        :method   => :post,
        :path     => "/apps/#{app}/releases",
        :body     => Heroku::Helpers.json_encode(body)
      )
    end
  end
end
