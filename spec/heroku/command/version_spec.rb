require "spec_helper"
require "heroku/command/version"

module Heroku::Command
  describe Version do

    it "shows version info" do
      stderr, stdout = execute("version")
      stderr.should == ""
      stdout.should == <<-STDOUT
#{Heroku.user_agent}
STDOUT
    end

  end
end
