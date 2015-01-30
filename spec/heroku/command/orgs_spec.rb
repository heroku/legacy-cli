require "spec_helper"
require "heroku/command/orgs"

module Heroku::Command
  describe Orgs do

    before(:each) do
      stub_core
      stub_organizations
    end

    after(:each) do
      Excon.stub({ :method => :get, :path => '/v1/user/info' }, { :status => 404 })
    end

    context(:index) do
      it "displays a message when you have no org memberships" do
        stderr, stdout = execute("orgs")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
You are not a member of any organizations.
STDOUT
      end

      it "lists orgs with roles that the user belongs to" do
        Excon.stub({ :method => :get, :path   => '/v1/user/info' },
          {
            :body   => MultiJson.dump({"organizations" => [{"organization_name" => "test-org", "role" => "collaborator"}, {"organization_name" => "test-org2", "role" => "admin"}], "user" => {}}),
            :status => 200
          }
        )

        stderr, stdout = execute("orgs")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
test-org   collaborator
test-org2  admin

STDOUT
      end

      it "labels a user's default organization" do
        Excon.stub({ :method => :get, :path   => '/v1/user/info' },
          {
            :body   => MultiJson.dump({"organizations" => [{"organization_name" => "test-org", "role" => "collaborator"}, {"organization_name" => "test-org2", "role" => "admin"}]}),
            :status => 200
          }
        )

        stderr, stdout = execute("orgs")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
test-org   collaborator
test-org2  admin

STDOUT
      end
    end

    context(:open) do
      before(:each) do
        require("launchy")
        expect(::Launchy).to receive(:open).with("https://dashboard.heroku.com/orgs/test-org/apps").once.and_return("")
      end

      it "opens the org specified in an argument" do
        _, stdout = execute("orgs:open --org test-org")
        expect(stdout).to eq <<-STDOUT
Opening web interface for test-org... done
STDOUT
      end

      it "opens the org specified in HEROKU_ORGANIZATION" do
        ENV['HEROKU_ORGANIZATION'] = 'test-org'
        _, stdout = execute("orgs:open")
        expect(stdout).to eq <<-STDOUT
Opening web interface for test-org... done
STDOUT
        ENV['HEROKU_ORGANIZATION'] = nil
      end
    end
  end
end
