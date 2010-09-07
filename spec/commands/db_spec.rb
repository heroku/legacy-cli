require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Db do
    before do
      @db = prepare_command(Db)
      @taps_client = mock('taps client')
    end

    it "pull database" do
      @db.stub!(:args).and_return(['postgres://postgres@localhost/db'])
      opts = { :database_url => 'postgres://postgres@localhost/db', :default_chunksize => 1000, :indexes_first => true }
      @db.should_receive(:taps_client).with(:pull, opts)
      @db.should_receive(:confirm).and_return(true)
      @db.pull
    end

    it "push database" do
      @db.stub!(:args).and_return(['postgres://postgres@localhost/db'])
      opts = { :database_url => 'postgres://postgres@localhost/db', :default_chunksize => 1000, :indexes_first => true }
      @db.should_receive(:taps_client).with(:push, opts)
      @db.should_receive(:confirm).and_return(true)
      @db.push
    end

    it "does not confirm a pull when --force is specified" do
      @db.stub!(:args).and_return(['postgres://postgres@localhost/db', '--force'])
      opts = { :database_url => 'postgres://postgres@localhost/db', :default_chunksize => 1000, :indexes_first => true }
      @db.should_receive(:taps_client).with(:pull, opts)
      @db.should_not_receive(:confirm)
      @db.pull
    end

    it "does not confirm a push when --force is specified" do
      @db.stub!(:args).and_return(['postgres://postgres@localhost/db', '--force'])
      opts = { :database_url => 'postgres://postgres@localhost/db', :default_chunksize => 1000, :indexes_first => true }
      @db.should_receive(:taps_client).with(:push, opts)
      @db.should_not_receive(:confirm)
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

    it "defaults host to 127.0.0.1 with a username" do
      @db.send(:uri_hash_to_url, {'scheme' => 'db', 'username' => 'user', 'path' => 'database'}).should == 'db://user@127.0.0.1/database'
    end

    it "handles the lack of a username properly" do
      @db.send(:uri_hash_to_url, {'scheme' => 'db', 'path' => 'database'}).should == 'db://127.0.0.1/database'
    end

    it "handles integer port number" do
      @db.send(:uri_hash_to_url, {'scheme' => 'db', 'path' => 'database', 'port' => 9000}).should == 'db://127.0.0.1:9000/database'
    end

    it "maps --tables to the taps table_filter option" do
      @db.stub!(:args).and_return(["--tables", "tags,countries", "sqlite://local.db"])
      opts = @db.send(:parse_taps_opts)
      opts[:table_filter].should == "(^tags$|^countries$)"
    end
  end
end
