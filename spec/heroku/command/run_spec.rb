require "spec_helper"
require "heroku/command/run"

module Heroku::Command
  describe Run do
    before(:each) do
      @cli = prepare_command(Run)
      @cli.stub(:options).and_return(:app => "myapp")
    end

    it "runs a rake command on the app" do
      @cli.stub!(:args).and_return(([ 'db:migrate' ]))
      @cli.heroku.should_receive(:start).
        with('myapp', 'rake db:migrate', :attached).
        and_return(['foo', 'bar', 'baz'])
      @cli.rake
    end

    it "runs a single console command on the app" do
      @cli.stub!(:args).and_return([ '2+2' ])
      @cli.heroku.should_receive(:console).with('myapp', '2+2')
      @cli.console
    end

    it "offers a console, opening and closing the session with the client" do
      @console = mock('heroku console')
      @cli.stub!(:console_history_read)
      @cli.stub!(:console_history_add)
      @cli.heroku.should_receive(:console).with('myapp').and_yield(@console)
      Readline.should_receive(:readline).and_return('exit')
      @cli.console
    end
  end
end
