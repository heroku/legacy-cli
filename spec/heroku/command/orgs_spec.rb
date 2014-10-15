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
            :body   => MultiJson.dump({"organizations" => [{"organization_name" => "test-org", "role" => "collaborator"}, {"organization_name" => "test-org2", "role" => "admin"}], "user" => {"default_organization" => "test-org2"}}),
            :status => 200
          }
        )

        stderr, stdout = execute("orgs")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
test-org   collaborator
test-org2  admin, default

STDOUT
      end
    end

    context(:default) do
      context "when a target org is specified" do
        it "sets the default org to the target" do
          expect(org_api).to receive(:set_default_org).with("test-org").once
          stderr, stdout = execute("orgs:default test-org")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Setting test-org as the default organization... done
STDOUT
        end

        it "removes the default org when the org name is 'personal'" do
          expect(org_api).to receive(:remove_default_org).once
          stderr, stdout = execute("orgs:default personal")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Setting personal account as default... done
STDOUT
        end

        it "removes the defautl org when the personal flag is passed" do
          expect(org_api).to receive(:remove_default_org).once
          stderr, stdout = execute("orgs:default --personal")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Setting personal account as default... done
STDOUT
        end

      end

      context "when no target is specified" do
        it "displays the default organization when present" do
          Excon.stub({ :method => :get, :path   => '/v1/user/info' },
            {
              :body   => MultiJson.dump({"user" => {"default_organization" => "test-org"}}),
              :status => 200
            }
          )

          stderr, stdout = execute("orgs:default")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
test-org is the default organization.
STDOUT
        end

        it "displays personal account as default when no org present" do
          stderr, stdout = execute("orgs:default")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Personal account is default.
STDOUT
        end
      end
    end

    context(:open) do
      before(:each) do
        require("launchy")
        expect(::Launchy).to receive(:open).with("https://dashboard.heroku.com/orgs/test-org/apps").once.and_return("")
      end

      it "opens the org specified in an argument" do
        stderr, stdout = execute("orgs:open --org test-org")
        expect(stdout).to eq <<-STDOUT
Opening web interface for test-org... done
STDOUT
      end

      it "opens the default org" do
        Excon.stub({ :method => :get, :path   => '/v1/user/info' },
          {
            :body   => MultiJson.dump({"organizations" => [{"organization_name" => "test-org"}], "user" => {"default_organization" => "test-org"}}),
            :status => 200
          }
        )

        stderr, stdout = execute("orgs:open")
        expect(stdout).to eq <<-STDOUT
Opening web interface for test-org... done
STDOUT
      end
    end
  end
end
