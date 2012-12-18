require "spec_helper"
require "heroku/command/drains"

describe Heroku::Command::Drains do

  describe "drains" do
    it "can list drains" do
      stub_core.list_drains("example").returns("drains")
      stderr, stdout = execute("drains")
      stderr.should == ""
      stdout.should == <<-STDOUT
drains
STDOUT
    end

    it "can add drains" do
      stub_core.add_drain("example", "syslog://localhost/add").returns("added")
      stderr, stdout = execute("drains:add syslog://localhost/add")
      stderr.should == ""
      stdout.should == <<-STDOUT
added
STDOUT
    end

    it "can remove drains" do
      stub_core.remove_drain("example", "syslog://localhost/remove").returns("removed")
      stderr, stdout = execute("drains:remove syslog://localhost/remove")
      stderr.should == ""
      stdout.should == <<-STDOUT
removed
STDOUT
    end
  end
end
