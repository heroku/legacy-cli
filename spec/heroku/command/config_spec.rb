require "spec_helper"
require "heroku/command/config"

module Heroku::Command
  describe Config do
    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar")
    end

    after(:each) do
      api.delete_app("example")
    end

    it "shows all configs" do
      api.put_config_vars("example", { 'FOO_BAR' => 'one', 'BAZ_QUX' => 'two' })
      stderr, stdout = execute("config")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== example Config Vars
BAZ_QUX: two
FOO_BAR: one
STDOUT
    end

    it "does not trim long values" do
      api.put_config_vars("example", { 'LONG' => 'A' * 60 })
      stderr, stdout = execute("config")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== example Config Vars
LONG: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
STDOUT
    end

    it "handles when value is nil" do
      api.put_config_vars("example", { 'FOO_BAR' => 'one', 'BAZ_QUX' => nil })
      stderr, stdout = execute("config")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== example Config Vars
BAZ_QUX: 
FOO_BAR: one
STDOUT
    end

    it "handles when value is a boolean" do
      api.put_config_vars("example", { 'FOO_BAR' => 'one', 'BAZ_QUX' => true })
      stderr, stdout = execute("config")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== example Config Vars
BAZ_QUX: true
FOO_BAR: one
STDOUT
    end

    it "shows configs in a shell compatible format" do
      api.put_config_vars("example", { 'A' => 'one', 'B' => 'two three' })
      stderr, stdout = execute("config --shell")
      stderr.should == ""
      stdout.should == <<-STDOUT
A=one
B=two three
STDOUT
    end

    it "shows a single config for get" do
      api.put_config_vars("example", { 'LONG' => 'A' * 60 })
      stderr, stdout = execute("config:get LONG")
      stderr.should == ""
      stdout.should == <<-STDOUT
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
STDOUT
    end

    context("set") do

      it "sets config vars" do
        stderr, stdout = execute("config:set A=1 B=2")
        stderr.should == ""
        stdout.should == <<-STDOUT
Setting config vars and restarting example... done, v1
A: 1
B: 2
      STDOUT
      end

      it "allows config vars with = in the value" do
        stderr, stdout = execute("config:set A=b=c")
        stderr.should == ""
        stdout.should == <<-STDOUT
Setting config vars and restarting example... done, v1
A: b=c
STDOUT
      end

      it "sets config vars without changing case" do
        stderr, stdout = execute("config:set a=b")
        stderr.should == ""
        stdout.should == <<-STDOUT
Setting config vars and restarting example... done, v1
a: b
STDOUT
      end

    end

    describe "config:unset" do

      it "exits with a help notice when no keys are provides" do
        stderr, stdout = execute("config:unset")
        stderr.should == <<-STDERR
 !    Usage: heroku config:unset KEY1 [KEY2 ...]
 !    Must specify KEY to unset.
STDERR
        stdout.should == ""
      end

      context "when one key is provided" do

        it "unsets a single key" do
          stderr, stdout = execute("config:unset A")
          stderr.should == ""
          stdout.should == <<-STDOUT
Unsetting A and restarting example... done, v1
STDOUT
        end
      end

      context "when more than one key is provided" do

        it "unsets all given keys" do
          stderr, stdout = execute("config:unset A B")
          stderr.should == ""
          stdout.should == <<-STDOUT
Unsetting A and restarting example... done, v1
Unsetting B and restarting example... done, v2
STDOUT
        end
      end
    end
  end
end
