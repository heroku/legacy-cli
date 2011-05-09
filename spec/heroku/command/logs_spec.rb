require "spec_helper"
require "heroku/command/logs"

describe Heroku::Command::Logs do
  describe "logs" do
    it "runs with no options" do
      stub_core.read_logs("myapp", [])
      execute "logs"
    end

    it "runs with options" do
      stub_core.read_logs("myapp", [
        "tail=1",
        "num=2",
        "ps=ps.3",
        "source=source.4"
      ])
      execute "logs --tail --num 2 --ps ps.3 --source source.4"
    end

    describe "with log output" do
      before(:each) do
        stub_core.read_logs("myapp", []).yields("2011-01-01T00:00:00+00:00 app[web.1]: test")
      end

      it "prettifies output" do
        execute "logs"
        output.should == "\e[36m2011-01-01T00:00:00+00:00 app[web.1]:\e[0m test"
      end

      it "does not use ansi if stdout is not a tty" do
        extend RR::Adapters::RRMethods
        stub(STDOUT).isatty.returns(false)
        execute "logs"
        output.should == "2011-01-01T00:00:00+00:00 app[web.1]: test"
        stub(STDOUT).isatty.returns(true)
      end
    end
  end

  describe "deprecated logs:cron" do
    it "can view cron logs" do
      stub_core.cron_logs("myapp").returns("the_cron_logs")
      execute "logs:cron"
      output.should =~ /the_cron_logs/
    end
  end

  describe "drains" do
    it "can list drains" do
      stub_core.list_drains("myapp").returns("drains")
      execute "logs:drains"
      output.should == "drains"
    end

    it "can add drains" do
      stub_core.add_drain("myapp", "syslog://localhost/add").returns("added")
      execute "logs:drains add syslog://localhost/add"
      output.should == "added"
    end

    it "can remove drains" do
      stub_core.remove_drain("myapp", "syslog://localhost/remove").returns("removed")
      execute "logs:drains remove syslog://localhost/remove"
      output.should == "removed"
    end

    it "can clear drains" do
      stub_core.clear_drains("myapp").returns("cleared")
      execute "logs:drains clear"
      output.should == "cleared"
    end

    it "errors on unknown subcommand" do
      lambda { execute "logs:drains foo" }.should fail_command("usage: heroku logs:drains <add | remove | clear>")
    end
  end
end
