require "spec_helper"
require "heroku/client/heroku_postgresql"
require "digest"

describe Heroku::Client::HerokuPostgresql do
  include Heroku::Helpers

  before do
    allow(Heroku::Auth).to receive(:user).and_return('user@example.com')
    allow(Heroku::Auth).to receive(:password).and_return('apitoken')
  end

  let(:attachment) { double('attachment', :resource_name => 'something-something-42', :starter_plan? => false) }
  let(:client)  { Heroku::Client::HerokuPostgresql.new(attachment) }

  describe 'api choosing' do
    it "sends an ingress request to the client for production plans" do
      expect(attachment).to receive(:starter_plan?).and_return(false)
      host = 'postgres-api.heroku.com'
      url  = "https://user@example.com:apitoken@#{host}/client/v11/databases/#{attachment.resource_name}/ingress"

      stub_request(:put, url).to_return(
        :body => json_encode({"message" => "ok"}),
        :status => 200
      )

      client.ingress

      expect(a_request(:put, url)).to have_been_made.once
    end

    it "sends an ingress request to the client for production plans" do
      allow(attachment).to receive_messages :starter_plan? => true
      host = 'postgres-starter-api.heroku.com'
      url  = "https://user@example.com:apitoken@#{host}/client/v11/databases/#{attachment.resource_name}/ingress"

      stub_request(:put, url).to_return(
        :body => json_encode({"message" => "ok"}),
        :status => 200
      )

      client.ingress

      expect(a_request(:put, url)).to have_been_made.once
    end
  end

  describe '#get_database' do
    let(:url) { "https://user@example.com:apitoken@postgres-api.heroku.com/client/v11/databases/#{attachment.resource_name}" }

    it 'works without the extended option' do
      stub_request(:get, url).to_return :body => '{}'
      client.get_database
      expect(a_request(:get, url)).to have_been_made.once
    end

    it 'works with the extended option' do
      url2 = url + '?extended=true'
      stub_request(:get, url2).to_return :body => '{}'
      client.get_database(true)
      expect(a_request(:get, url2)).to have_been_made.once
    end

    it "retries on error, then raises" do
      stub_request(:get, url).to_return(:body => "error", :status => 500)
      allow(client).to receive(:sleep)
      expect { client.get_database }.to raise_error RestClient::InternalServerError
      expect(a_request(:get, url)).to have_been_made.times(4)
    end
  end

end
