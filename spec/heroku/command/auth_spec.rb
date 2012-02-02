require "spec_helper"
require "heroku/command/auth"

describe Heroku::Command::Auth do
  describe "auth:token" do
    it "displays the user's api key" do
      Heroku::Auth.should_receive(:api_key).and_return("foo_token")
      execute "auth:token"
      output.should == "foo_token"
    end
  end
end
