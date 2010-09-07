require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Logs do
    before do
      @cli = prepare_command(Logs)
    end

    it "shows the app logs" do
      @cli.heroku.should_receive(:logs).with('myapp').and_return('logs')
      @cli.should_receive(:display).with('logs')
      @cli.index
    end

    it "shows the app cron logs" do
      @cli.heroku.should_receive(:cron_logs).with('myapp').and_return('cron logs')
      @cli.should_receive(:display).with('cron logs')
      @cli.cron
    end
  end
end