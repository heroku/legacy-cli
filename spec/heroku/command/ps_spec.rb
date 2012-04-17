require "spec_helper"
require "heroku/command/ps"

describe Heroku::Command::Ps do
  describe "ps:dynos" do
    it "displays the current number of dynos" do
      stub_core.info("myapp").returns(:dynos => 5)
      stderr, stdout = execute("ps:dynos")
      stderr.should == ""
      stdout.should == <<-STDOUT
~ `heroku ps:dynos QTY` has been deprecated and replaced with `heroku ps:scale dynos=QTY`
myapp is running 5 dynos
STDOUT
    end

    it "sets the number of dynos" do
      stub_core.set_dynos("myapp", "5").returns(5)
      stderr, stdout = execute("ps:dynos 5")
      stderr.should == ""
      stdout.should == <<-STDOUT
~ `heroku ps:dynos QTY` has been deprecated and replaced with `heroku ps:scale dynos=QTY`
myapp now running 5 dynos
STDOUT
    end

    it "errors out on cedar apps" do
      stub_core.info("myapp").returns(:dynos => 5, :stack => "cedar")
      lambda { execute "ps:dynos" }.should raise_error(Heroku::Command::CommandFailed)
    end
  end

  describe "ps:workers" do
    it "displays the current number of workers" do
      stub_core.info("myapp").returns(:workers => 5)
      stderr, stdout = execute("ps:workers")
      stderr.should == ""
      stdout.should == <<-STDOUT
~ `heroku ps:workers QTY` has been deprecated and replaced with `heroku ps:scale workers=QTY`
myapp is running 5 workers
STDOUT
    end

    it "sets the number of workers" do
      stub_core.set_workers("myapp", "5").returns(5)
      stderr, stdout = execute("ps:workers 5")
      stderr.should == ""
      stdout.should == <<-STDOUT
~ `heroku ps:workers QTY` has been deprecated and replaced with `heroku ps:scale workers=QTY`
myapp now running 5 workers
STDOUT
    end

    it "errors out on cedar apps" do
      stub_core.info("myapp").returns(:workers => 5, :stack => "cedar")
      lambda { execute "ps:dynos" }.should raise_error(Heroku::Command::CommandFailed)
    end
  end

  describe "ps" do
    before(:each) do
      stub_core.ps("myapp").returns([
        { "process" => "ps.1", "state" => "running", "elapsed" => 600, "command" => "bin/bash ps1" },
        { "process" => "ps.2", "state" => "running", "elapsed" => 600, "command" => "bin/bash ps2" }
      ])
    end

    it "displays processes" do
      stderr, stdout = execute("ps")
      stderr.should == ""
      stdout.should == <<-STDOUT
Process  State            Command
-------  ---------------  ------------
ps.1     running for 10m  bin/bash ps1
ps.2     running for 10m  bin/bash ps2
STDOUT
    end
  end

  describe "ps:restart" do
    it "restarts all processes with no args" do
      stub_core.ps_restart("myapp", {})
      stderr, stdout = execute("ps:restart")
      stderr.should == ""
      stdout.should == <<-STDOUT
Restarting processes... done
STDOUT
    end

    it "restarts one process" do
      stub_core.ps_restart("myapp", :ps => "ps.1")
      stderr, stdout = execute("ps:restart ps.1")
      stderr.should == ""
      stdout.should == <<-STDOUT
Restarting ps.1 process... done
STDOUT
    end

    it "restarts a type of process" do
      stub_core.ps_restart("myapp", :type => "ps")
      stderr, stdout = execute("ps:restart ps")
      stderr.should == ""
      stdout.should == <<-STDOUT
Restarting ps processes... done
STDOUT
    end
  end

  describe "ps:scale" do
    it "can scale using key/value format" do
      stub_core.ps_scale("myapp", :type => "ps", :qty => "5").returns(5)
      stderr, stdout = execute("ps:scale ps=5")
      stderr.should == ""
      stdout.should == <<-STDOUT
Scaling ps processes... done, now running 5
STDOUT
    end

    it "can scale relative amounts" do
      stub_core.ps_scale("myapp", :type => "ps", :qty => "+2").returns(5)
      stub_core.ps_scale("myapp", :type => "sp", :qty => "-2").returns(1)
      stub_core.ps_scale("myapp", :type => "ot", :qty => "7").returns(10)
      stderr, stdout = execute("ps:scale ps+2 sp-2 ot=7")
      stderr.should == ""
      stdout.should == <<-STDOUT
Scaling ot processes... done, now running 10
Scaling ps processes... done, now running 5
Scaling sp processes... done, now running 1
STDOUT
    end

    it "can scale a process with a number in its name" do
      stub_core.ps_scale("myapp", :type => "ps2web", :qty => "5").returns(5)
      stderr, stdout = execute("ps:scale ps2web=5")
      stderr.should == ""
      stdout.should == <<-STDOUT
Scaling ps2web processes... done, now running 5
STDOUT
    end
  end
end
