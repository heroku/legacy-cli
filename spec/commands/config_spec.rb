require File.dirname(__FILE__) + '/../base'

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

		it "shows just one config" do
			@config.stub!(:args).and_return(['b'])
			@config.heroku.should_receive(:config_vars).and_return({ 'A' => 'one', 'B' => 'two' })
			@config.should_not_receive(:display).with('A => one')
			@config.should_receive(:display).with('B => two')
			@config.index
		end

		it "sets config vars" do
			@config.stub!(:args).and_return(['a=1', 'b=2'])
			@config.heroku.should_receive(:set_config_vars).with('myapp', {'a'=>'1','b'=>'2'})
			@config.index
		end

		it "trims long values" do
			@config.heroku.should_receive(:config_vars).and_return({ 'LONG' => 'A' * 60 })
			@config.should_receive(:display).with('LONG => AAAAAAAAAAAAAAAA...AAAAAAAAAAAAAAAA')
			@config.index
		end

		it "unsets config key" do
			@config.stub!(:args).and_return(['a'])
			@config.heroku.should_receive(:unset_config_var).with('myapp', 'a')
			@config.unset
		end

		it "resets config" do
			@config.heroku.should_receive(:reset_config_vars).with('myapp')
			@config.reset
		end
	end
end
