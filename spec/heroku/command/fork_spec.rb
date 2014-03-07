require "spec_helper"
require "heroku/command/fork"
require "heroku/client/cisaurus"

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
        stub_cisaurus.copy_slug.returns("/v1/jobs/4099d263-bf67-4c0b-80f5-64a5d25598fd")
        stub_cisaurus.job_done?.returns(true)
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
      it "doesn't attempt to fork to the same app" do
        lambda do
          execute("fork example")
        end.should raise_error(Heroku::Command::CommandFailed, /same app/)
      end

      it "confirms before deleting the app" do
        stub_cisaurus.copy_slug { raise SocketError }
        begin
          execute("fork example-fork")
        rescue SocketError
        end
        api.get_apps.body.map { |app| app["name"] }.should ==
          %w( example example-fork )
      end

      it "deletes fork app on error, before re-raising" do
        stub(Heroku::Command).confirm_command.returns(true)
        stub_cisaurus.copy_slug { raise SocketError }
        api.get_apps.body.map { |app| app["name"] }.should == %w( example )
      end
    end
  end
end
