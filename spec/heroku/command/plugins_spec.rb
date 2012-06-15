require "spec_helper"
require "heroku/command/plugins"

module Heroku::Command
  include SandboxHelper

  describe Plugins do

    before do
      @plugin = Heroku::Plugin.new("git://github.com/heroku/Plugin.git")
    end

    context("install") do

      before do
        Heroku::Plugin.should_receive(:new).with('git://github.com/heroku/Plugin.git').and_return(@plugin)
        @plugin.should_receive(:install).and_return(true)
      end

      it "installs plugins" do
        Heroku::Plugin.should_receive(:load_plugin).and_return(true)
        stderr, stdout = execute("plugins:install git://github.com/heroku/Plugin.git")
        stderr.should == ""
        stdout.should == <<-STDOUT
Installing Plugin... done
STDOUT
      end

      it "does not install plugins that do not load" do
        Heroku::Plugin.should_receive(:load_plugin).and_raise("error")
        @plugin.should_receive(:uninstall).and_return(true)
        stderr, stdout = execute("plugins:install git://github.com/heroku/Plugin.git")
        stderr.should == <<-STDERR
 !    Could not initialize Plugin: error
 !    
 !    Are you attempting to install a Rails plugin? If so, use the following:
 !    
 !    Rails 2.x:
 !    script/plugin install git://github.com/heroku/Plugin.git
 !    
 !    Rails 3.x:
 !    rails plugin install git://github.com/heroku/Plugin.git
STDERR
        stdout.should == <<-STDOUT
Installing Plugin... failed
STDOUT
      end

    end

    context("uninstall") do

      before do
        Heroku::Plugin.should_receive(:new).with('Plugin').and_return(@plugin)
      end

      it "uninstalls plugins" do
        @plugin.should_receive(:uninstall).and_return(true)
        stderr, stdout = execute("plugins:uninstall Plugin")
        stderr.should == ""
        stdout.should == <<-STDOUT
Uninstalling Plugin... done
STDOUT
      end

      it "does not uninstall plugins that do not exist" do
        @plugin.should_receive(:uninstall).and_return(false)
        stderr, stdout = execute("plugins:uninstall Plugin")
        stderr.should == <<-STDERR
 !    Plugin "Plugin" not found.
STDERR
        stdout.should == <<-STDOUT
Uninstalling Plugin... failed
STDOUT
      end

    end
  end
end
