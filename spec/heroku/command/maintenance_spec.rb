require "spec_helper"
require "heroku/command/maintenance"

module Heroku::Command
  describe Maintenance do

    it "turns on maintenance mode for the app" do
      stub_core.maintenance("myapp", :on)
      stderr, stdout = execute("maintenance:on")
      stderr.should == ""
      stdout.should == <<-STDOUT
Maintenance mode enabled.
STDOUT
    end

    it "turns off maintenance mode for the app" do
      stub_core.maintenance("myapp", :off)
      stderr, stdout = execute("maintenance:off")
      stderr.should == ""
      stdout.should == <<-STDOUT
Maintenance mode disabled.
STDOUT
    end

  end
end
