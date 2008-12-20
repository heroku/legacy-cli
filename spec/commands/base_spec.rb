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
				Dir.stub!(:pwd).and_return('/home/dev/myapp')
				@base.stub!(:heroku).and_return(@client)
			end

			it "attempts to find the app via the --app argument" do
				@base.stub!(:args).and_return(['--app', 'myapp'])
				@base.extract_app.should == 'myapp'
			end

			it "parses the app from git config when there's only one remote" do
				File.stub!(:exists?).with('/home/dev/myapp/.git/config').and_return(true)
				File.stub!(:read).with('/home/dev/myapp/.git/config').and_return("
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

			it "uses the remote named after the current folder name when there are multiple" do
				File.stub!(:exists?).with('/home/dev/myapp/.git/config').and_return(true)
				File.stub!(:read).with('/home/dev/myapp/.git/config').and_return("
[remote \"heroku_backup\"]
	url = git@heroku.com:myapp-backup.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
[remote \"heroku\"]
	url = git@heroku.com:myapp.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
				")
				@base.extract_app.should == 'myapp'
			end

			it "raises when cannot determine which app is it" do
				File.should_receive(:exists?).with('/home/dev/myapp/.git/config').and_return(true)
				File.stub!(:read).with('/home/dev/myapp/.git/config').and_return("
[remote \"heroku_backup\"]
	url = git@heroku.com:app1.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
[remote \"heroku\"]
	url = git@heroku.com:app2.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
				")
				lambda { @base.extract_app }.should raise_error(Heroku::Command::CommandFailed)
			end
		end

		context "option parsing" do
			it "extracts options from args" do
				@base.stub!(:args).and_return(%w( a b --something value c d ))
				@base.extract_option('--something').should == 'value'
			end

			it "accepts options without value" do
				@base.stub!(:args).and_return(%w( a b --something))
				@base.extract_option('--something', 'default').should == 'default'
			end

			it "doesn't consider parameters as a value" do
				@base.stub!(:args).and_return(%w( a b --something --something-else c d))
				@base.extract_option('--something', 'default').should == 'default'
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