require "spec_helper"
require "heroku/command/run"

describe Heroku::Command::Run do
  describe "run:rake" do
    it "runs a rake command" do
      stub_core.ps_run("myapp", :attach => true, :command => "rake foo", :ps_env => get_terminal_environment, :type => "rake").returns("rendezvous_url" => "rendezvous://s1.runtime.heroku.com:5000/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx")
      stub_rendezvous.start do
        $stdout.puts("rake_output")
      end
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
