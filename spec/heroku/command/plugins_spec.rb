require "spec_helper"
require "heroku/command/plugins"

module Heroku::Command
  include SandboxHelper

  describe Plugins do

    before do
      @plugin = Heroku::Plugin.new("git://github.com/heroku/plugin.git")
    end

    context("install") do

      before do
        Heroku::Plugin.should_receive(:new).with('git://github.com/heroku/plugin.git').and_return(@plugin)
        @plugin.should_receive(:install).and_return(true)
      end

      it "installs plugins" do
        Heroku::Plugin.should_receive(:load_plugin).and_return(true)
        stderr, stdout = execute("plugins:install git://github.com/heroku/plugin.git")
        stderr.should == ""
        stdout.should == <<-STDOUT
plugin installed
STDOUT
      end

      it "does not install plugins that do not load" do
        Heroku::Plugin.should_receive(:load_plugin).and_raise("error")
        @plugin.should_receive(:uninstall).and_return(true)
        stderr, stdout = execute("plugins:install git://github.com/heroku/plugin.git")
        stderr.should == <<-STDERR
 !    Could not initialize plugin: error
 !    
 !    Are you attempting to install a Rails plugin? If so, use the following:
 !    
 !    Rails 2.x:
 !    script/plugin install git://github.com/heroku/plugin.git
 !    
 !    Rails 3.x:
 !    rails plugin install git://github.com/heroku/plugin.git
STDERR
        # FIXME: sometimes stdout contains failed
        #stdout.should == ""
      end

    end

    context("uninstall") do

      before do
        Heroku::Plugin.should_receive(:new).with('plugin').and_return(@plugin)
      end

      it "uninstalls plugins" do
        @plugin.should_receive(:uninstall).and_return(true)
        stderr, stdout = execute("plugins:uninstall plugin")
        stderr.should == ""
        stdout.should == <<-STDOUT
plugin uninstalled
STDOUT
      end

      it "does not uninstall plugins that do not exist" do
        @plugin.should_receive(:uninstall).and_return(false)
        stderr, stdout = execute("plugins:uninstall plugin")
        stderr.should == <<-STDERR
 !    Plugin "plugin" not found.
STDERR
        # FIXME: sometimes stdout contains failed
        #stdout.should == ""
      end

    end
  end
end
