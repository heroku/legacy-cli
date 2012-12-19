require "spec_helper"
require "heroku/command/run"
require "heroku/helpers"

describe Heroku::Command::Run do

  include Heroku::Helpers

  before(:each) do
    stub_core
    api.post_app("name" => "example", "stack" => "cedar")
  end

  after(:each) do
    api.delete_app("example")
  end

  describe "run" do
    it "runs a command" do
      stub_rendezvous.start { $stdout.puts "output" }

      stderr, stdout = execute("run bin/foo")
      stderr.should == ""
      stdout.should == <<-STDOUT
Running `bin/foo` attached to terminal... up, run.1
output
STDOUT
    end
  end

  describe "run:detached" do
    it "runs a command detached" do
      stderr, stdout = execute("run:detached bin/foo")
      stderr.should == ""
      stdout.should == <<-STDOUT
Running `bin/foo` detached... up, run.1
Use `heroku logs -p run.1` to view the output.
STDOUT
    end
  end

  describe "run:rake" do
    it "runs a rake command" do
      stub_rendezvous.start { $stdout.puts("rake_output") }

      stderr, stdout = execute("run:rake foo")
      stderr.should == ""
      stdout.should == <<-STDOUT
WARNING: `heroku run:rake` has been deprecated. Please use `heroku run rake` instead.
Running `rake foo` attached to terminal... up, run.1
rake_output
STDOUT
    end

    it "shows the proper command in the deprecation warning" do
      stub_rendezvous.start { $stdout.puts("rake_output") }

      stderr, stdout = execute("rake foo")
      stderr.should == ""
      stdout.should == <<-STDOUT
WARNING: `heroku rake` has been deprecated. Please use `heroku run rake` instead.
Running `rake foo` attached to terminal... up, run.1
rake_output
STDOUT
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
      stub_core.console("example", "bash foo").returns("foo_output")
      stderr, stdout = execute("run:console bash foo")
      stderr.should == ""
      stdout.should == <<-STDOUT
foo_output
STDOUT
    end
  end
end
