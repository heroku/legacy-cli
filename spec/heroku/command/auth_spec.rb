require "spec_helper"
require "heroku/command/auth"

describe Heroku::Command::Auth do
  describe "auth:token" do
    it "displays the user's api key" do
      Heroku::Auth.should_receive(:api_key).and_return("foo_token")
      stderr, stdout = execute("auth:token")
      stderr.should == ""
      stdout.should == <<-STDOUT
foo_token
STDOUT
    end
  end
end
