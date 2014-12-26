module Heroku
  class API
    def get_app_buildpacks_v3(app)
      headers = { 'Accept' => 'application/vnd.heroku+json; version=3' }
      request(
      :expects  => [ 200, 206 ],
      :headers  => headers,
      :method   => :get,
      :path     => "/apps/#{app}/buildpack-installations"
      )
    end

    def put_app_buildpacks_v3(app, body={})
      headers = {
        'Accept'       => 'application/vnd.heroku+json; version=3',
        'Content-Type' => 'application/json'
      }
      request(
      :expects  => 200,
      :headers  => headers,
      :method   => :put,
      :path     => "/apps/#{app}/buildpack-installations",
      :body     => Heroku::Helpers.json_encode(body)
      )
    end
  end
end
