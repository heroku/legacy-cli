require "spec_helper"
require "heroku/command/config"

module Heroku::Command
  describe Config do
    before do
      @config = prepare_command(Config)
    end

    it "shows all configs" do
      stub_core.config_vars("myapp").returns({ 'A' => 'one', 'B' => 'two' })
      stderr, stdout = execute("config")
      stderr.should == ""
      stdout.should == <<-STDOUT
A => one
B => two
STDOUT
    end

    it "does not trim long values" do
      stub_core.config_vars("myapp").returns({ 'LONG' => 'A' * 60 })
      stderr, stdout = execute("config")
      stderr.should == ""
      stdout.should == <<-STDOUT
LONG => AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
STDOUT
    end

    it "shows configs in a shell compatible format" do
      stub_core.config_vars("myapp").returns({ 'A' => 'one', 'B' => 'two' })
      stderr, stdout = execute("config --shell")
      stderr.should == ""
      stdout.should == <<-STDOUT
A=one
B=two
STDOUT
    end

    context("add") do

      before do
        stub_core.release("myapp", "current").returns({"name" => "v123"})
      end

      it "sets config vars" do
        stub_core.add_config_vars("myapp", {"a" => "1", "b" => "2"})
        stderr, stdout = execute("config:add a=1 b=2")
        stderr.should == ""
        stdout.should == <<-STDOUT
Adding config vars and restarting app... done, v123
  a => 1
  b => 2
      STDOUT
      end

      it "allows config vars with = in the value" do
        stub_core.add_config_vars("myapp", {"a" => "b=c"})
        stderr, stdout = execute("config:add a=b=c")
        stderr.should == ""
        stdout.should == <<-STDOUT
Adding config vars and restarting app... done, v123
  a => b=c
STDOUT
      end

    end

    describe "config:remove" do

      before do
        stub_core.release("myapp", "current").returns({"name" => "v123"})
      end

      it "exits with a help notice when no keys are provides" do
        lambda { execute("config:remove") }.should raise_error(CommandFailed, "Usage: heroku config:remove KEY1 [KEY2 ...]")
      end

      context "when one key is provided" do

        it "removes a single key" do
          stub_core.remove_config_var("myapp", "a")
          stderr, stdout = execute("config:remove a")
          stderr.should == ""
          stdout.should == <<-STDOUT
Removing a and restarting app... done, v123
STDOUT
        end
      end

      context "when more than one key is provided" do
        let(:args) { ['a', 'b'] }

        it "removes all given keys" do
          stub_core.remove_config_var("myapp", "a")
          stub_core.remove_config_var("myapp", "b")
          stderr, stdout = execute("config:remove a b")
          stderr.should == ""
          stdout.should == <<-STDOUT
Removing a and restarting app... done, v123
Removing b and restarting app... done, v123
STDOUT
        end
      end
    end
  end
end
