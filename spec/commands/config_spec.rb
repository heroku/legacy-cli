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

		it "sets configs and restart the app" do
			@config.stub!(:args).and_return(['a=1', 'b=2'])
			@config.heroku.should_receive(:set_config_var).with('myapp', 'a', '1')
			@config.heroku.should_receive(:set_config_var).with('myapp', 'b', '2')
			@config.heroku.should_receive(:restart).with('myapp')
			@config.index
		end

		it "trims long values" do
			@config.heroku.should_receive(:config_vars).and_return({ 'LONG' => 'A' * 60 })
			@config.should_receive(:display).with('LONG => AAAAAAAAAAAAAAAA...AAAAAAAAAAAAAAAA')
			@config.index
		end
	end
end