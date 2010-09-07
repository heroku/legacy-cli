require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  include SandboxHelper

  describe Plugins do
    before do
      @command = prepare_command(Plugins)
      @plugin  = mock('heroku plugin')
    end

    it "installs plugins" do
      @command.stub!(:args).and_return(['git://github.com/heroku/plugin.git'])
      Heroku::Plugin.should_receive(:new).with('git://github.com/heroku/plugin.git').and_return(@plugin)
      @plugin.should_receive(:install).and_return(true)
      @command.install
    end

    it "uninstalls plugins" do
      @command.stub!(:args).and_return(['plugin'])
      Heroku::Plugin.should_receive(:new).with('plugin').and_return(@plugin)
      @plugin.should_receive(:uninstall)
      @command.uninstall
    end
  end
end
