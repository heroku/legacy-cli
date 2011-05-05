require "spec_helper"
require "heroku/command/config"

module Heroku::Command
  describe Config do
    before do
      @config = prepare_command(Config)
    end

    it "shows all configs" do
      @config.heroku.should_receive(:config_vars).and_return({ 'A' => 'one', 'B' => 'two' })
      @config.should_receive(:display).with('A => one')
      @config.should_receive(:display).with('B => two')
      @config.index
    end

    it "does not trim long values" do
      @config.heroku.should_receive(:config_vars).and_return({ 'LONG' => 'A' * 60 })
      @config.should_receive(:display).with('LONG => AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA')
      @config.index
    end

    it "shows configs in a shell compatible format" do
      @config.stub!(:options).and_return({:shell => true})
      @config.heroku.should_receive(:config_vars).and_return({ 'A' => 'one', 'B' => 'two' })
      @config.should_receive(:display).with('A=one')
      @config.should_receive(:display).with('B=two')
      @config.index
    end

    it "sets config vars" do
      @config.stub!(:args).and_return(['a=1', 'b=2'])
      @config.heroku.should_receive(:add_config_vars).with('myapp', {'a'=>'1','b'=>'2'})
      @config.add
    end

    it "allows config vars with = in the value" do
      @config.stub!(:args).and_return(['a=b=c'])
      @config.heroku.should_receive(:add_config_vars).with('myapp', {'a'=>'b=c'})
      @config.add
    end

    it "unsets config vars" do
      @config.stub!(:args).and_return(['a'])
      @config.heroku.should_receive(:remove_config_var).with('myapp', 'a')
      @config.remove
    end
  end
end
