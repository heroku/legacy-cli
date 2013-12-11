class Heroku::Client::Organizations

  # stub GET /v1/user/info
  Excon.stub(:expects => 200, :method => :get, :path => %r{^/v1/user/info$} ) do |params|
    {
      :body => "",
      :status => 404
    }
  end

end