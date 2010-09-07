require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Ps do
    before do
      @cli = prepare_command(Ps)
    end

    it "lists processes" do
      @cli.heroku.should_receive(:ps).and_return([
        { 'command' => 'rake', 'elapsed' => 3 }
      ])
      @cli.index
    end
  end
end
