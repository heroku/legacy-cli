require "spec_helper"
require "heroku/command/config"

module Heroku::Command
  describe Config do
    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar")

      Excon.stub(method: :get, path: %r{^/apps/example/releases/current}) do
        { body: MultiJson.dump({ 'name' => 'v1' }), status: 200 }
      end
    end

    after(:each) do
      api.delete_app("example")
      Excon.stubs.shift
    end

    it "shows all configs" do
      api.put_config_vars("example", { 'FOO_BAR' => 'one', 'BAZ_QUX' => 'two' })
      stderr, stdout = execute("config")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== example Config Vars
BAZ_QUX: two
FOO_BAR: one
STDOUT
    end

    it "does not trim long values" do
      api.put_config_vars("example", { 'LONG' => 'A' * 60 })
      stderr, stdout = execute("config")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== example Config Vars
LONG: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
STDOUT
    end

    it "handles when value is nil" do
      api.put_config_vars("example", { 'FOO_BAR' => 'one', 'BAZ_QUX' => nil })
      stderr, stdout = execute("config")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== example Config Vars
BAZ_QUX: 
FOO_BAR: one
STDOUT
    end

    it "handles when value is a boolean" do
      api.put_config_vars("example", { 'FOO_BAR' => 'one', 'BAZ_QUX' => true })
      stderr, stdout = execute("config")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== example Config Vars
BAZ_QUX: true
FOO_BAR: one
STDOUT
    end

    it "shows configs in a shell compatible format" do
      api.put_config_vars("example", { 'A' => 'one', 'B' => 'two three', 'C' => "foo&bar" })
      stderr, stdout = execute("config --shell")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
A=one
B=two\\ three
C=foo\\&bar
STDOUT
    end

    it "shows a single config for get" do
      api.put_config_vars("example", { 'LONG' => 'A' * 60 })
      stderr, stdout = execute("config:get LONG")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
STDOUT
    end

    context("set") do

      it "sets config vars" do
        stderr, stdout = execute("config:set A=1 B=2")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Setting config vars and restarting example... done, v1
A: 1
B: 2
      STDOUT
      end

      it "allows config vars with = in the value" do
        stderr, stdout = execute("config:set A=b=c")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Setting config vars and restarting example... done, v1
A: b=c
STDOUT
      end

      it "sets config vars without changing case" do
        stderr, stdout = execute("config:set a=b")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Setting config vars and restarting example... done, v1
a: b
STDOUT
      end

      it "sets config vars without values" do
        str_stdin = StringIO.new("b\n")
        class << str_stdin
          def tty?
            true
          end
        end
        stderr, stdout = execute("config:set a", {:stdin => str_stdin})
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Enter value for 'a':Setting config vars and restarting example... done, v1
a: b
STDOUT
      end

      it "sets config vars with and without values" do
        str_stdin = StringIO.new("b\nd\n")
        class << str_stdin
          def tty?
            true
          end
        end
        stderr, stdout = execute("config:set a=a b c=c d", {:stdin => str_stdin})
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Enter value for 'b':Enter value for 'd':Setting config vars and restarting example... done, v1
a: a
b: b
c: c
d: d
STDOUT
      end

      it "sets config vars from pipe" do
        str_stdin = StringIO.new("b\n")
        class << str_stdin
          def tty?
            false
          end
        end
        stderr, stdout = execute("config:set a=a b c=c", {:stdin => str_stdin})
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Setting config vars and restarting example... done, v1
a: a
b: b
c: c
STDOUT
      end

      it "exist with message that redirect can only be to one key" do
        str_stdin = StringIO.new("b\n")
        class << str_stdin
          def tty?
            false
          end
        end
        stderr, stdout = execute("config:set a b", {:stdin => str_stdin})
        expect(stderr).to eq <<-STDERR
 !    Cannot redirect to multiple keys.
STDERR
        expect(stdout).to eq("")
      end


    end

    describe "config:unset" do

      it "exits with a help notice when no keys are provides" do
        stderr, stdout = execute("config:unset")
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku config:unset KEY1 [KEY2 ...]
 !    Must specify KEY to unset.
STDERR
        expect(stdout).to eq("")
      end

      context "when one key is provided" do

        it "unsets a single key" do
          stderr, stdout = execute("config:unset A")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Unsetting A and restarting example... done, v1
STDOUT
        end
      end

      context "when more than one key is provided" do

        it "unsets all given keys" do
          request_number = 1
          Excon.stub(method: :get, path: %r{^/apps/example/releases/current}) do |req|
            response = { body: MultiJson.dump({ 'name' => "v#{request_number}" }), status: 200 }
            request_number += 1
            response
          end

          stderr, stdout = execute("config:unset A B")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Unsetting A and restarting example... done, v1
Unsetting B and restarting example... done, v2
STDOUT
        end
      end
    end
  end
end
