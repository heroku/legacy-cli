require File.expand_path("./base", File.dirname(__FILE__))
require "cgi"
require "heroku-postgresql/client"

def hk_pg_api_stub(method, path)
  stub_request(method, "https://user:pass@shogun.heroku.com/client/#{path}")
end

def hk_pg_api_request(method, path)
  a_request(method, "https://user:pass@shogun.heroku.com/client/#{path}")
end

describe HerokuPostgresql::Client do
  before do
    @user = "user"
    @pass = "pass"
    @dbname = "dbname"
    @client = HerokuPostgresql::Client.new(@user, @pass, @dbname)
  end

  it "sends an ingress request to the client" do
    hk_pg_api_stub(:put, "databases/#{@dbname}/ingress").to_return(
      :body => {:message => "ok"}.to_json,
      :status => 200
    )

    @client.ingress

    hk_pg_api_request(:put, "databases/#{@dbname}/ingress").should have_been_made.once
  end

  it "retries on error, then raises" do
    hk_pg_api_stub(:get, "databases/#{@dbname}").to_return(:body => "error", :status => 500)
    @client.stub(:sleep)
    lambda { @client.get_database }.should raise_error RestClient::InternalServerError
    hk_pg_api_request(:get, "databases/#{@dbname}").should have_been_made.times(4)
  end

end
