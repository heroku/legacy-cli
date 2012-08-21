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
        Heroku::Plugin.should_receive(:load_plugin).and_return(false)
        @plugin.should_receive(:uninstall).and_return(true)
        stderr, stdout = execute("plugins:install git://github.com/heroku/Plugin.git")
        stderr.should == '' # normally would have error, but mocks/stubs don't allow
        stdout.should == "Installing Plugin... " # also inaccurate, would end in ' failed'
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
        stderr, stdout = execute("plugins:uninstall Plugin")
        stderr.should == <<-STDERR
 !    Plugin plugin not found.
STDERR
        stdout.should == <<-STDOUT
Uninstalling Plugin... failed
STDOUT
      end

    end

    context("update") do

      before do
        Heroku::Plugin.should_receive(:new).with('Plugin').and_return(@plugin)
      end

      it "updates plugin by name" do
        @plugin.should_receive(:update).and_return(true)
        stderr, stdout = execute("plugins:update Plugin")
        stderr.should == ""
        stdout.should == <<-STDOUT
Updating Plugin... done
STDOUT
      end

      it "updates all plugins" do
        Heroku::Plugin.should_receive(:list).and_return([], [], ['Plugin'])
        @plugin.should_receive(:update).and_return(true)
        stderr, stdout = execute("plugins:update")
        stderr.should == ""
        stdout.should == <<-STDOUT
Updating Plugin... done
STDOUT
      end

      it "does not update plugins that do not exist" do
        stderr, stdout = execute("plugins:update Plugin")
        stderr.should == <<-STDERR
 !    Plugin plugin not found.
STDERR
        stdout.should == <<-STDOUT
Updating Plugin... failed
STDOUT
      end

    end

  end
end
