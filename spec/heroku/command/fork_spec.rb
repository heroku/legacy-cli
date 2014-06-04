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
        stderr.should == ""
        stdout.should == <<-STDOUT
Creating fork example-fork... done
Copying slug... done
Copying config vars... done
Fork complete, view it at http://example-fork.herokuapp.com/
STDOUT
      end

      it "copies slug" do
        Heroku::API.any_instance.should_receive(:get_releases_v3).with("example", "version ..; order=desc,max=1;").and_call_original
        Heroku::API.any_instance.should_receive(:post_release_v3).with("example-fork", "SLUG_ID", "Forked from example").and_call_original
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
        api.get_config_vars("example-fork").body.should == config_vars
      end

      it "re-provisions add-ons" do
        addons = ["pgbackups:basic", "deployhooks:http"].sort
        addons.each { |a| api.post_addon("example", a) }
        execute("fork example-fork")
        api.get_addons("example-fork").body.collect { |info| info["name"] }.sort.should == addons
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
          e.message.should == "No releases on example"
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
            e.message.should == "No slug on example"
        ensure
          Excon.stubs.shift
        end
      end

      it "doesn't attempt to fork to the same app" do
        lambda do
          execute("fork example")
        end.should raise_error(Heroku::Command::CommandFailed, /same app/)
      end

      it "confirms before deleting the app" do
        Excon.stub({:path => "/apps/example/releases"}, {:status => 500})
        begin
          execute("fork example-fork")
        rescue Heroku::API::Errors::ErrorWithResponse
        ensure
          Excon.stubs.shift
        end
        api.get_apps.body.map { |app| app["name"] }.should ==
          %w( example example-fork )
      end

      it "deletes fork app on error, before re-raising" do
        stub(Heroku::Command).confirm_command.returns(true)
        api.get_apps.body.map { |app| app["name"] }.should == %w( example )
      end
    end
  end
end
