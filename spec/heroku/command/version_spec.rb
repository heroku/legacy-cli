require "spec_helper"
require "heroku/command/version"

module Heroku::Command
  describe Version do

    it "shows version info" do
      stderr, stdout = execute("version")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
#{Heroku.user_agent}
heroku-cli/4.0.0-4f2c5c5 (amd64-darwin) go1.5
You have no installed plugins.
STDOUT
    end

  end
end
