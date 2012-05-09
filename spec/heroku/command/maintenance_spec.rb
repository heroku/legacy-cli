require "spec_helper"
require "heroku/command/maintenance"

module Heroku::Command
  describe Maintenance do

    before(:each) do
      stub_core
      api.post_app("name" => "myapp", "stack" => "cedar")
    end

    after(:each) do
      api.delete_app("myapp")
    end

    it "turns on maintenance mode for the app" do
      stderr, stdout = execute("maintenance:on")
      stderr.should == ""
      stdout.should == <<-STDOUT
Enabling maintenance mode for myapp... done
STDOUT
    end

    it "turns off maintenance mode for the app" do
      stderr, stdout = execute("maintenance:off")
      stderr.should == ""
      stdout.should == <<-STDOUT
Disabling maintenance mode for myapp... done
STDOUT
    end

  end
end
