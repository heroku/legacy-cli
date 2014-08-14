require "spec_helper"
require "heroku/client/pgbackups"
require "heroku/helpers"

describe Heroku::Client::Pgbackups do

  include Heroku::Helpers

  let(:path)   { "http://id:password@pgbackups.heroku.com" }
  let(:client) { Heroku::Client::Pgbackups.new path+'/api' }
  let(:transfer_path) { path + '/client/transfers' }

  describe "api" do
    let(:version) { Heroku::Client.version }

    it 'still has a heroku gem version' do
      expect(version).to be
      expect(version.split(/\./).first.to_i).to be >= 2
    end

    it 'includes the heroku gem version' do
      stub_request(:get, transfer_path)
      client.get_transfers
      expect(a_request(:get, transfer_path).with(
        :headers => {'X-Heroku-Gem-Version' => version}
      )).to have_been_made.once
    end
  end

  describe "create transfers" do
    it "sends a request to the client" do
      stub_request(:post, transfer_path).to_return(
        :body => json_encode({"message" => "success"}),
        :status => 200
      )

      client.create_transfer("postgres://from", "postgres://to", "FROMNAME", "TO_NAME")

      expect(a_request(:post, transfer_path)).to have_been_made.once
    end
  end

end
