require File.dirname(__FILE__) + '/../base'

module Heroku::Command
	describe Maintenance do
		before do
			@m = prepare_command(Maintenance)
		end

		it "turns on maintenance mode for the app" do
			@m.heroku.should_receive(:maintenance).with('myapp', :on)
			@m.on
		end

		it "turns off maintenance mode for the app" do
			@m.heroku.should_receive(:maintenance).with('myapp', :off)
			@m.off
		end
	end
end
