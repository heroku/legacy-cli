require "heroku/api/releases_v3"
require "spec_helper"
require "heroku/command/fork"

module Heroku::Command

  describe Fork do

    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar")
    end

    after(:each) do
      api.delete_app("example")
      begin
        api.delete_app("example-fork")
      rescue Heroku::API::Errors::NotFound
      end
    end

    context "successfully" do

      before(:each) do
        Excon.stub({ :method => :get,
                     :path => "/apps/example/releases" },
                   { :body => [{"slug" => {"id" => "SLUG_ID"}}],
                     :status => 206})

        Excon.stub({ :method => :post,
                     :path => "/apps/example-fork/releases"},
                   { :status => 201})
      end

      after(:each) do
        Excon.stubs.shift
        Excon.stubs.shift
      end

      it "forks an app" do
        stderr, stdout = execute("fork example-fork")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Creating fork example-fork... done
Copying slug... done
Copying config vars... done
Fork complete, view it at http://example-fork.herokuapp.com/
STDOUT
      end

      it "copies slug" do
        from_info = api.get_app("example").body
        expect_any_instance_of(Heroku::API).to receive(:get_releases_v3).with("example", "version ..; order=desc,max=1;").and_call_original
        expect_any_instance_of(Heroku::API).to receive(:post_release_v3).with("example-fork",
                                                                              "SLUG_ID",
                                                                              :description => "Forked from example",
                                                                              :deploy_type => "fork",
                                                                              :deploy_source => from_info["id"]).and_call_original
        execute("fork example-fork")
      end

      it "copies config vars" do
        config_vars = {
            "SECRET"     => "imasecret",
            "FOO"        => "bar",
            "LANG_ENV"   => "production"
        }
        api.put_config_vars("example", config_vars)
        execute("fork example-fork")
        expect(api.get_config_vars("example-fork").body).to eq(config_vars)
      end

      it "re-provisions add-ons" do
        api.post_addon("example", "heroku-postgresql:hobby-dev")
        execute("fork example-fork")
        expect(api.get_addons("example-fork").body[0]["name"]).to eq("heroku-postgresql:hobby-dev")
      end
    end

    describe "error handling" do
      it "fails if no source release exists" do
        begin
          Excon.stub({ :method => :get,
                       :path => "/apps/example/releases" },
                     { :body => [],
                       :status => 206})
          execute("fork example-fork")
          raise
        rescue Heroku::Command::CommandFailed => e
          expect(e.message).to eq("No releases on example")
        ensure
          Excon.stubs.shift
        end
      end

      it "fails if source slug does not exist" do
        begin
          Excon.stub({ :method => :get,
                       :path => "/apps/example/releases" },
                     { :body => [{"slug" => nil}],
                       :status => 206})
          execute("fork example-fork")
          raise
        rescue Heroku::Command::CommandFailed => e
            expect(e.message).to eq("No slug on example")
        ensure
          Excon.stubs.shift
        end
      end

      it "doesn't attempt to fork to the same app" do
        expect do
          execute("fork example")
        end.to raise_error(Heroku::Command::CommandFailed, /same app/)
      end

      it "confirms before deleting the app" do
        Excon.stub({:path => "/apps/example/releases"}, {:status => 500})
        begin
          execute("fork example-fork")
        rescue Heroku::API::Errors::ErrorWithResponse
        ensure
          Excon.stubs.shift
        end
        expect(api.get_apps.body.map { |app| app["name"] }).to eq(
          %w( example example-fork )
        )
      end

      it "deletes fork app on error, before re-raising" do
        stub(Heroku::Command).confirm_command.returns(true)
        expect(api.get_apps.body.map { |app| app["name"] }).to eq(%w( example ))
      end
    end
  end
end
