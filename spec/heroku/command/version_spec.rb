require "spec_helper"
require "heroku/command/version"

module Heroku::Command
  describe Version do

    it "shows version info" do
      stderr, stdout = execute("version")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
#{Heroku.user_agent}
You have no installed plugins.
STDOUT
    end

  end
end
