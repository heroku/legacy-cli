require File.dirname(__FILE__) + '/../base'

module Heroku::Command
	describe Base do
		before do
			@args = [1, 2]
			@base = Base.new(@args)
			@base.stub!(:display)
			@client = mock('heroku client', :host => 'heroku.com')
		end

		it "initializes the heroku client with the Auth command" do
			Heroku::Command.should_receive(:run_internal).with('auth:client', @args)
			@base.heroku
		end

		context "detecting the app" do
			before do
				@base.stub!(:heroku).and_return(@client)
			end

			it "attempts to find the app via the --app argument" do
				@base.stub!(:args).and_return(['--app', 'myapp'])
				@base.extract_app.should == 'myapp'
			end

			it "parses the app from git config when there's only one remote" do
				File.stub!(:exists?).and_return(true)
				File.stub!(:read).and_return("
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote \"heroku\"]
	url = git@heroku.com:myapp.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
				")
				@base.extract_app.should == 'myapp'
			end

			context "detecting the app with multiple remotes" do
				before do
					File.stub!(:exists?).with(anything).and_return(true)
					File.stub!(:read).with(anything).and_return("
[remote \"staging\"]
	url = git@heroku.com:myapp-staging.git
	fetch = +refs/heads/*:refs/remotes/staging/*
[remote \"production\"]
	url = git@heroku.com:myapp.git
	fetch = +refs/heads/*:refs/remotes/production/*
					")
				end

				it "uses the remote named after the current folder name when there are multiple" do
					Dir.stub!(:pwd).and_return('/home/dev/myapp')
					@base.extract_app.should == 'myapp'
				end

				it "accepts a --remote argument to choose the app from the remote name" do
					@base.stub!(:args).and_return(['--remote', 'staging'])
					@base.extract_app.should == 'myapp-staging'
				end

				it "raises when cannot determine which app is it" do
					lambda { @base.extract_app }.should raise_error(Heroku::Command::CommandFailed)
				end
			end
		end

		context "option parsing" do
			it "extracts options from args" do
				@base.stub!(:args).and_return(%w( a b --something value c d ))
				@base.extract_option('--something').should == 'value'
			end

			it "accepts options without value" do
				@base.stub!(:args).and_return(%w( a b --something))
				@base.extract_option('--something').should be_true
			end

			it "doesn't consider parameters as a value" do
				@base.stub!(:args).and_return(%w( a b --something --something-else c d))
				@base.extract_option('--something').should be_true
			end

			it "accepts a default value" do
				@base.stub!(:args).and_return(%w( a b --something))
				@base.extract_option('--something', 'default').should == 'default'
			end

			it "is not affected by multiple arguments with the same value" do
				@base.stub!(:args).and_return(%w( --arg1 val --arg2 val ))
				@base.extract_option('--arg1').should == 'val'
				@base.args.should == ['--arg2', 'val']
			end
		end

		describe "formatting" do
			it "formats app urls (http and git), displayed as output on create and other commands" do
				@base.stub!(:heroku).and_return(mock('heroku client', :host => 'example.com'))
				@base.app_urls('test').should == "http://test.example.com/ | git@example.com:test.git"
			end
		end
	end
end