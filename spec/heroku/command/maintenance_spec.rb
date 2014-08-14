require "spec_helper"
require "heroku/command/maintenance"

module Heroku::Command
  describe Maintenance do

    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar")
    end

    after(:each) do
      api.delete_app("example")
    end

    it "displays off for maintenance mode of an app" do
      stderr, stdout = execute("maintenance")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
off
STDOUT
    end

    it "displays on for maintenance mode of an app" do
      api.post_app_maintenance('example', '1')

      stderr, stdout = execute("maintenance")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
on
STDOUT
    end

    it "turns on maintenance mode for the app" do
      stderr, stdout = execute("maintenance:on")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Enabling maintenance mode for example... done
STDOUT
    end

    it "turns off maintenance mode for the app" do
      stderr, stdout = execute("maintenance:off")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Disabling maintenance mode for example... done
STDOUT
    end

  end
end
