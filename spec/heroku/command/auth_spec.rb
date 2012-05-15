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
  
  describe "auth:whoami" do
    it "displays the user's email address" do
      Heroku::Auth.should_receive(:user).and_return("jebediah@heroku.com")
      stderr, stdout = execute("auth:whoami")
      stderr.should == ""
      stdout.should == <<-STDOUT
jebediah@heroku.com
STDOUT
    end

  end

end
