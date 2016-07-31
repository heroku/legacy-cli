require "spec_helper"
require "heroku/command/auth"

describe Heroku::Command::Auth do
  describe "auth:token" do
    it "displays the user's api key" do
      stderr, stdout = execute("auth:token")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
apikey01
STDOUT
    end
  end
end
