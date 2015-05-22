require "spec_helper"
require "heroku/command/logs"

describe Heroku::Command::Logs do
  describe "logs" do
    it "runs with no options" do
      stub_core.read_logs("example", [])
      execute "logs"
    end

    it "runs with options" do
      stub_core.read_logs("example", [
        "tail=1",
        "num=2",
        "ps=ps.3",
        "source=source.4"
      ])
      execute "logs --tail --num 2 --ps ps.3 --source source.4"
    end

    describe "with log output" do
      before(:each) do
        stub_core.read_logs("example", []).yields("2011-01-01T00:00:00+00:00 app[web.1]: test")
      end

      it "prettifies tty output" do
        old_stdout_isatty = $stdout.isatty
        stub($stdout).isatty.returns(true)
        stderr, stdout = execute("logs")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
\e[36m2011-01-01T00:00:00+00:00 app[web.1]:\e[0m test
STDOUT
        stub($stdout).isatty.returns(old_stdout_isatty)
      end

      it "does not use ansi if stdout is not a tty" do
        old_stdout_isatty = $stdout.isatty
        stub($stdout).isatty.returns(false)
        stderr, stdout = execute("logs")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
2011-01-01T00:00:00+00:00 app[web.1]: test
STDOUT
        stub($stdout).isatty.returns(old_stdout_isatty)
      end

      it "does not use ansi if TERM is not set" do
        term = ENV.delete("TERM")
        stderr, stdout = execute("logs")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
2011-01-01T00:00:00+00:00 app[web.1]: test
STDOUT
        ENV["TERM"] = term
      end

      it "uses ansi if --force-colors is passed, even if stdout is not a tty and TERM is not set" do
        old_term = ENV.delete("TERM")
        old_stdout_isatty = $stdout.isatty
        stub($stdout).isatty.returns(false)
        stderr, stdout = execute("logs --force-colors")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
\e[36m2011-01-01T00:00:00+00:00 app[web.1]:\e[0m test
STDOUT
        ENV["TERM"] = old_term
        stub($stdout).isatty.returns(old_stdout_isatty)
      end
    end
  end
end
