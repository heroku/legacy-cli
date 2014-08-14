require "spec_helper"
require "heroku/command/drains"

describe Heroku::Command::Drains do

  describe "drains" do
    it "can list drains" do
      stub_core.list_drains("example").returns("drains")
      stderr, stdout = execute("drains")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
drains
STDOUT
    end

    it "can add drains" do
      stub_core.add_drain("example", "syslog://localhost/add").returns("added")
      stderr, stdout = execute("drains:add syslog://localhost/add")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
added
STDOUT
    end

    it "can remove drains" do
      stub_core.remove_drain("example", "syslog://localhost/remove").returns("removed")
      stderr, stdout = execute("drains:remove syslog://localhost/remove")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
removed
STDOUT
    end
  end
end
