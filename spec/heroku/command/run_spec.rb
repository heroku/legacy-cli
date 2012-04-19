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
      lambda { execute "run:rake" }.should fail_command("Usage: heroku run:rake COMMAND")
    end

    it "gets an http APP_CRASHED" do
      stub_core.start("myapp", "rake foo", :attached) { raise(Heroku::Client::AppCrashed, "error_page") }
      stderr, stdout = execute("run:rake foo")
      stderr.should == <<-STDERR
 !    Couldn't run rake
 !    error_page
STDERR
      # FIXME: sometimes contains "failed\n"
      # stdout.should == ""
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
