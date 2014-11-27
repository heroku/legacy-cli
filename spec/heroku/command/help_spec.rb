require "spec_helper"
require "heroku/command/apps"
require "heroku/command/help"

describe Heroku::Command::Help do

  describe "help" do
    it "should show root help with no args" do
      stderr, stdout = execute("help")
      expect(stderr).to eq("")
      expect(stdout).to include "Usage: heroku COMMAND [--app APP] [command-specific-options]"
      expect(stdout).to include "apps"
      expect(stdout).to include "help"
    end

    it "should show command help and namespace help when ambiguous" do
      stderr, stdout = execute("help apps")
      expect(stderr).to eq("")
      expect(stdout).to include "heroku apps"
      expect(stdout).to include "list your apps"
      expect(stdout).to include "Additional commands"
      expect(stdout).to include "apps:create"
    end

    it "should show only command help when not ambiguous" do
      stderr, stdout = execute("help apps:create")
      expect(stderr).to eq("")
      expect(stdout).to include "heroku apps:create"
      expect(stdout).to include "create a new app"
      expect(stdout).not_to include "Additional commands"
    end

    it "should show command help with --help" do
      stderr, stdout = execute("apps:create --help")
      expect(stderr).to eq("")
      expect(stdout).to include "Usage: heroku apps:create"
      expect(stdout).to include "create a new app"
      expect(stdout).not_to include "Additional commands"
    end

    it "should redirect if the command is an alias" do
      stderr, stdout = execute("help create")
      expect(stderr).to eq("")
      expect(stdout).to include "Alias: create redirects to apps:create"
      expect(stdout).to include "Usage: heroku apps:create"
      expect(stdout).to include "create a new app"
      expect(stdout).not_to include "Additional commands"
    end

    it "should show if the command does not exist" do
      stderr, stdout = execute("help sudo:sandwich")
      expect(stderr).to eq <<-STDERR
 !    sudo:sandwich is not a heroku command. See `heroku help`.
STDERR
      expect(stdout).to eq("")
    end

    it "should show help with naked -h" do
      stderr, stdout = execute("-h")
      expect(stderr).to eq("")
      expect(stdout).to include "Usage: heroku COMMAND"
    end

    it "should show help with naked --help" do
      stderr, stdout = execute("--help")
      expect(stderr).to eq("")
      expect(stdout).to include "Usage: heroku COMMAND"
    end

    describe "with legacy help" do
      require "helper/legacy_help"

      it "displays the legacy group in the namespace list" do
        stderr, stdout = execute("help")
        expect(stderr).to eq("")
        expect(stdout).to include "Foo Group"
      end

      it "displays group help" do
        stderr, stdout = execute("help foo")
        expect(stderr).to eq("")
        expect(stdout).to include "do a bar to foo"
        expect(stdout).to include "do a baz to foo"
      end

      it "displays legacy command-specific help" do
        stderr, stdout = execute("help foo:bar")
        expect(stderr).to eq("")
        expect(stdout).to include "do a bar to foo"
      end
    end
  end
end
