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
        expect(Heroku::Plugin).to receive(:new).with('git://github.com/heroku/Plugin.git').and_return(@plugin)
        expect(@plugin).to receive(:install).and_return(true)
      end

      it "installs plugins" do
        expect(Heroku::Plugin).to receive(:load_plugin).and_return(true)
        stderr, stdout = execute("plugins:install git://github.com/heroku/Plugin.git")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Installing git://github.com/heroku/Plugin.git... done
STDOUT
      end

      it "does not install plugins that do not load" do
        expect(Heroku::Plugin).to receive(:load_plugin).and_return(false)
        expect(@plugin).to receive(:uninstall).and_return(true)
        stderr, stdout = execute("plugins:install git://github.com/heroku/Plugin.git")
        expect(stderr).to eq('') # normally would have error, but mocks/stubs don't allow
        expect(stdout).to eq("Installing git://github.com/heroku/Plugin.git... ") # also inaccurate, would end in ' failed'
      end

    end

    context("uninstall") do

      before do
        expect(Heroku::Plugin).to receive(:new).with('Plugin').and_return(@plugin)
      end

      it "uninstalls plugins" do
        expect(@plugin).to receive(:uninstall).and_return(true)
        stderr, stdout = execute("plugins:uninstall Plugin")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Uninstalling Plugin... done
STDOUT
      end

      it "does not uninstall plugins that do not exist" do
        stderr, stdout = execute("plugins:uninstall Plugin")
        expect(stderr).to eq <<-STDERR
 !    Plugin plugin not found.
STDERR
        expect(stdout).to eq <<-STDOUT
Uninstalling Plugin... failed
STDOUT
      end

    end

    context("update") do

      before do
        expect(Heroku::Plugin).to receive(:new).with('Plugin').and_return(@plugin)
      end

      it "updates plugin by name" do
        expect(@plugin).to receive(:update).and_return(true)
        stderr, stdout = execute("plugins:update Plugin")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Updating Plugin... done
STDOUT
      end

      it "updates all plugins" do
        allow(Heroku::Plugin).to receive(:list).and_return(['Plugin'])
        expect(@plugin).to receive(:update).and_return(true)
        stderr, stdout = execute("plugins:update")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Updating Plugin... done
STDOUT
      end

      it "does not update plugins that do not exist" do
        stderr, stdout = execute("plugins:update Plugin")
        expect(stderr).to eq <<-STDERR
 !    Plugin plugin not found.
STDERR
        expect(stdout).to eq <<-STDOUT
Updating Plugin... failed
STDOUT
      end

    end

  end
end
