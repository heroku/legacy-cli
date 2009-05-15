require File.dirname(__FILE__) + '/../base'

module Heroku::Command
	describe Addons do
		before do
			@addons = prepare_command(Addons)
		end

		it "lists addons" do
			@addons.heroku.should_receive(:addons).and_return([])
			@addons.list
		end

		it "adds addons" do
			@addons.stub!(:args).and_return(%w( addon1 addon2 ))
			@addons.heroku.should_receive(:install_addon).with('myapp', 'addon1')
			@addons.heroku.should_receive(:install_addon).with('myapp', 'addon2')
			@addons.add
		end

		it "asks the user to confirm billing when API responds with 402" do
			@addons.stub!(:args).and_return(%w( addon1 ))
			e = RestClient::RequestFailed.new
			e.stub!(:http_code).and_return(402)
			@addons.heroku.should_receive(:install_addon).and_raise(e)
			@addons.should_receive(:confirm_billing).and_return(false)
			@addons.add
		end

		it "removes addons" do
			@addons.stub!(:args).and_return(%w( addon1 ))
			@addons.heroku.should_receive(:uninstall_addon).with('myapp', 'addon1')
			@addons.remove
		end

		it "clears addons" do
			@addons.heroku.should_receive(:installed_addons).with('myapp').and_return([{ 'name' => 'addon1' }])
			@addons.heroku.should_receive(:uninstall_addon).with('myapp', 'addon1')
			@addons.clear
		end
	end
end