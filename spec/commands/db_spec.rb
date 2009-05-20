require File.dirname(__FILE__) + '/../base'

module Heroku::Command
	describe Db do
		before do
			@db = prepare_command(Db)
			@taps_client = mock('taps client')
		end

		it "pull database" do
			@db.stub!(:args).and_return(['postgres://postgres@localhost/db'])
			@db.should_receive(:taps_client).with('postgres://postgres@localhost/db').and_yield(@taps_client)
			@taps_client.should_receive(:cmd_receive)
			@db.pull
		end

		it "push database" do
			@db.stub!(:args).and_return(['postgres://postgres@localhost/db'])
			@db.should_receive(:taps_client).with('postgres://postgres@localhost/db').and_yield(@taps_client)
			@taps_client.should_receive(:cmd_send)
			@db.push
		end

		it "resets the app's database specified with --app if user confirms" do
			@db.stub!(:ask).and_return('y')
			@db.stub!(:autodetected_app).and_return(false)
			@db.heroku.stub!(:info).and_return({})
			@db.heroku.should_receive(:database_reset).with('myapp')
			@db.reset
		end

		it "doesn't reset the app's database if the user doesn't confirms" do
			@db.stub!(:ask).and_return('no')
			@db.stub!(:args).and_return(['--app', 'myapp'])
			@db.heroku.stub!(:info).and_return({})
			@db.heroku.should_not_receive(:database_reset)
			@db.reset
		end
          describe "#uri_hash_to_url" do
            it "defaults host to 127.0.0.1 with a username" do
              @db.stub!(:escape).and_return('user')
              @db.send(:uri_hash_to_url, {'scheme' => 'db', 'username' => 'user', 'path' => 'database'}).should == 'db://user@127.0.0.1/database'
            end
          end
	end
end
