require "spec_helper"
require "heroku/helpers"
require "heroku-postgresql/client"
require 'digest'

def shogun_path(path)
  "https://shogun.heroku.com/client/v10/#{path}"
end

def hk_pg_api_stub(method, path)
  stub_request(method, shogun_path(path))
end

def hk_pg_api_request(method, path)
  a_request(method, shogun_path(path))
end

describe HerokuPostgresql::Client do
  include Heroku::Helpers
  let(:url)     { 'postgres://somewhere/somedb' }
  let(:url_sha) { Digest::SHA2.hexdigest url }
  let(:client)  { HerokuPostgresql::Client.new(url) }


  it "sends an ingress request to the client" do
    hk_pg_api_stub(:put, "databases/#{url_sha}/ingress").to_return(
      :body => json_encode({:message => "ok"}),
      :status => 200
    )

    client.ingress

    hk_pg_api_request(:put, "databases/#{url_sha}/ingress").should have_been_made.once
  end

  it "retries on error, then raises" do
    hk_pg_api_stub(:get, "databases/#{url_sha}").to_return(:body => "error", :status => 500)
    client.stub(:sleep)
    lambda { client.get_database }.should raise_error RestClient::InternalServerError
    hk_pg_api_request(:get, "databases/#{url_sha}").should have_been_made.times(4)
  end

end
