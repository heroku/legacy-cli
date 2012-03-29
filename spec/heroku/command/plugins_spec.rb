require "spec_helper"
require "heroku/command/plugins"

module Heroku::Command
  include SandboxHelper

  describe Plugins do
    before do
      @command = prepare_command(Plugins)
      @plugin  = mock('heroku plugin')
      @plugin.stub(:name).and_return("plugin")
    end

    it "installs plugins" do
      @command.stub!(:args).and_return(['git://github.com/heroku/plugin.git'])
      Heroku::Plugin.should_receive(:new).with('git://github.com/heroku/plugin.git').and_return(@plugin)
      Heroku::Plugin.should_receive(:load_plugin).and_return(true)
      @plugin.should_receive(:install).and_return(true)
      @command.install
    end

    it "does not install plugins that do not load" do
      @command.stub!(:args).and_return(['git://github.com/heroku/plugin.git'])
      Heroku::Plugin.should_receive(:new).with('git://github.com/heroku/plugin.git').and_return(@plugin)
      Heroku::Plugin.should_receive(:load_plugin).and_raise("error")
      @plugin.should_receive(:install).and_return(true)
      @command.should_receive(:installation_failed).with(@plugin, "error")
      @command.install
    end

    it "uninstalls plugins" do
      @command.stub!(:args).and_return(['plugin'])
      Heroku::Plugin.should_receive(:new).with('plugin').and_return(@plugin)
      @plugin.should_receive(:uninstall).and_return(true)
      @command.uninstall
    end

    it "does not uninstall plugins that do not exist" do
      @command.stub!(:args).and_return(['plugin'])
      Heroku::Plugin.should_receive(:new).with('plugin').and_return(@plugin)
      @plugin.should_receive(:uninstall).and_return(false)
      STDERR.should_receive(:puts).with(%{ !    Plugin "plugin" not found.})
      lambda { @command.uninstall }.should raise_error(SystemExit)
    end
  end
end
