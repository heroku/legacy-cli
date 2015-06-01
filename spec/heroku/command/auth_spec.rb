require "spec_helper"
require "heroku/command/auth"

describe Heroku::Command::Auth do
  describe "auth" do
    it "displays heroku help auth" do
      stderr, stdout = execute("auth")

      expect(stderr).to eq("")
      expect(stdout).to include "Additional commands"
      expect(stdout).to include "auth:login"
      expect(stdout).to include "auth:logout"
    end
  end

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
