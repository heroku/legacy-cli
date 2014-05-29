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

    def post_release_v3(app, slug_id, description=nil)
      body = { 'slug' => slug_id }
      body.merge!('description' => description) if description
      request(
        :expects  => 201,
        :headers  => {
          'Accept'       => 'application/vnd.heroku+json; version=3',
          'Content-Type' => 'application/json'
        },
        :method   => :post,
        :path     => "/apps/#{app}/releases",
        :body     => Heroku::Helpers.json_encode(body)
      )
    end
  end
end
