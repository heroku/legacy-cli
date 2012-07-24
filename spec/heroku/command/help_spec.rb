require "spec_helper"
require "heroku/command/apps"
require "heroku/command/help"

describe Heroku::Command::Help do

  describe "help" do
    it "should show root help with no args" do
      stderr, stdout = execute("help")
      stderr.should == ""
      stdout.should include "Usage: heroku COMMAND [--app APP] [command-specific-options]"
      stdout.should include "apps"
      stdout.should include "help"
    end

    it "should show command help and namespace help when ambigious" do
      stderr, stdout = execute("help apps")
      stderr.should == ""
      stdout.should include "heroku apps"
      stdout.should include "list your apps"
      stdout.should include "Additional commands"
      stdout.should include "apps:create"
    end

    it "should show only command help when not ambiguous" do
      stderr, stdout = execute("help apps:create")
      stderr.should == ""
      stdout.should include "heroku apps:create"
      stdout.should include "create a new app"
      stdout.should_not include "Additional commands"
    end

    it "should show command help with --help" do
      stderr, stdout = execute("apps:create --help")
      stderr.should == ""
      stdout.should include "Usage: heroku apps:create"
      stdout.should include "create a new app"
      stdout.should_not include "Additional commands"
    end

    it "should redirect if the command is an alias" do
      stderr, stdout = execute("help create")
      stderr.should == ""
      stdout.should include "Alias: create redirects to apps:create"
      stdout.should include "Usage: heroku apps:create"
      stdout.should include "create a new app"
      stdout.should_not include "Additional commands"
    end

    it "should show if the command does not exist" do
      stderr, stdout = execute("help sudo:sandwich")
      stderr.should == <<-STDERR
 !    sudo:sandwich is not a heroku command. See `heroku help`.
STDERR
      stdout.should == ""
    end

    it "should show help with naked -h" do
      stderr, stdout = execute("-h")
      stderr.should == ""
      stdout.should include "Usage: heroku COMMAND"
    end

    it "should show help with naked --help" do
      stderr, stdout = execute("--help")
      stderr.should == ""
      stdout.should include "Usage: heroku COMMAND"
    end

    describe "with legacy help" do
      require "helper/legacy_help"

      it "displays the legacy group in the namespace list" do
        stderr, stdout = execute("help")
        stderr.should == ""
        stdout.should include "Foo Group"
      end

      it "displays group help" do
        stderr, stdout = execute("help foo")
        stderr.should == ""
        stdout.should include "do a bar to foo"
        stdout.should include "do a baz to foo"
      end

      it "displays legacy command-specific help" do
        stderr, stdout = execute("help foo:bar")
        stderr.should == ""
        stdout.should include "do a bar to foo"
      end
    end
  end
end
