require File.dirname(__FILE__) + '/../base'

module Heroku::Command
	describe Bundles do
		before do
			@bundles = prepare_command(Bundles)
		end

		it "lists bundles" do
			@bundles.heroku.should_receive(:bundles).with('myapp').and_return([])
			@bundles.list
		end

		it "captures a bundle with the specified name" do
			@bundles.stub!(:args).and_return(['mybundle'])
			@bundles.heroku.should_receive(:bundle_capture).with('myapp', 'mybundle')
			@bundles.capture
		end

		it "captures a bundle with no name" do
			@bundles.heroku.should_receive(:bundle_capture).with('myapp', nil)
			@bundles.capture
		end

		it "destroys a bundle" do
			@bundles.stub!(:args).and_return(['mybundle'])
			@bundles.heroku.should_receive(:bundle_destroy).with('myapp', 'mybundle')
			@bundles.destroy
		end

		it "downloads a bundle to appname.tar.gz" do
			@bundles.stub!(:args).and_return(['mybundle'])
			@bundles.heroku.should_receive(:bundle_url).with('myapp', 'mybundle').and_return('https://s3.amazonaws.com/herokubundles/123.tar.gz')
			RestClient.should_receive(:get).with('https://s3.amazonaws.com/herokubundles/123.tar.gz').and_return('bundle contents')
			@file = mock('bundle file')
			File.should_receive(:open).with('myapp.tar.gz', 'wb').and_yield(@file)
			@file.should_receive(:write).with('bundle contents')
			File.stub!(:stat).and_return(mock('app stat', :size => 1234))
			@bundles.download
		end

		it "animates a bundle" do
			@bundles.stub!(:args).and_return(['mybundle'])
			@bundles.heroku.should_receive(:create).with(nil, :origin_bundle_app => 'myapp', :origin_bundle => 'mybundle')
			@bundles.animate
		end
	end
end
