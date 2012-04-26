require "spec_helper"
require "heroku/command/run"

describe Heroku::Command::Run do
  describe "run:rake" do
    it "runs a rake command" do
      stub_core.start("myapp", "rake foo", :attached).returns(["rake_output\n"])
      stderr, stdout = execute("run:rake foo")
      stderr.should == ""
      stdout.should == <<-STDOUT
rake_output
STDOUT
    end

    it "requires a command" do
      lambda { execute "run:rake" }.should fail_command("Usage: heroku rake COMMAND")
    end
  end

  describe "run:console" do
    it "runs a console session" do
      console = stub(Heroku::Client::ConsoleSession)
      stub_core.console.returns(console)
      stderr, stdout = execute("run:console")
      stderr.should == ""
      stdout.should == ""
    end

    it "runs a console command" do
      stub_core.console("myapp", "bash foo").returns("foo_output")
      stderr, stdout = execute("run:console bash foo")
      stderr.should == ""
      stdout.should == <<-STDOUT
foo_output
STDOUT
    end
  end
end
