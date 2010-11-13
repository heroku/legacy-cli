require File.expand_path("./base", File.dirname(__FILE__))
require "cgi"
require "pgbackups/client"

def pgbackups_api_stub(method, path)
  stub_request(method, "http://id:password@pgbackups.heroku.com#{path}")
end

def pgbackups_api_request(method, path)
  a_request(method, "http://id:password@pgbackups.heroku.com#{path}")
end

describe PGBackups::Client do
  before do
    @client = PGBackups::Client.new("http://id:password@pgbackups.heroku.com/api")
  end

  describe "transfers" do
    it "sends a request to the client" do
      pgbackups_api_stub(:post, "/client/transfers").to_return(
        :body => {:message => "success"}.to_json,
        :status => 200
      )

      @client.create_transfer("postgres://from", "postgres://to", "FROMNAME", "TO_NAME")

      pgbackups_api_request(:post, "/client/transfers").should have_been_made.once
    end
  end

end
