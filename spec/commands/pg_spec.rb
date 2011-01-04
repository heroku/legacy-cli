require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Pg do
    before do
      @pg = prepare_command(Pg)
      @pg.stub!(:config_vars).and_return({
        "DATABASE_URL" => "postgres://database_url",
        "SHARED_DATABASE_URL" => "postgres://other_database_url",
        "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://database_url"
      })
      @pg.stub!(:args).and_return(["--db", "DATABASE_URL"])
      @pg.heroku.stub!(:info).and_return({})
    end

    it "resets the app's database if user confirms" do
      @pg.stub!(:confirm_command).and_return(true)

      fake_client = mock("heroku_postgresql_client")
      fake_client.should_receive("reset")

      @pg.should_receive(:heroku_postgresql_client).with("postgres://database_url").and_return(fake_client)

      @pg.reset
    end

    it "doesn't reset the app's database if the user doesn't confirm" do
      @pg.stub!(:confirm_command).and_return(false)
      @pg.should_not_receive(:heroku_postgresql_client)
      @pg.reset
    end

    context "info" do
      it "requests the info from the server" do
        fake_client = mock("heroku_postgresql_client")
        fake_client.should_receive("get_database").and_return({
          :state => "available",
          :state_updated_at => Time.now.to_s,
          :num_bytes => 123123,
          :num_tables => 10,
          :created_at => Time.now.to_s
        })

        @pg.should_receive(:heroku_postgresql_client).with("postgres://database_url").and_return(fake_client)
        @pg.info
      end
    end

    context "promotion" do
      it "promotes the specified database" do
        @pg.stub!(:args).and_return(['--db', 'SHARED_DATABASE_URL'])
        @pg.stub!(:confirm_command).and_return(true)

        @pg.heroku.should_receive(:add_config_vars).with("myapp", {"DATABASE_URL" => @pg.config_vars["SHARED_DATABASE_URL"]})

        @pg.promote
      end

      it "fails if no database is specified" do
        @pg.stub(:args).and_return([])
        @pg.stub!(:confirm_command).and_return(true)

        @pg.heroku.should_not_receive(:add_config_vars)
        @pg.should_receive(:abort).with(" !   Usage: heroku pg:promote --db <DATABASE>").and_raise(SystemExit)

        lambda { @pg.promote }.should raise_error SystemExit
      end

      it "does not repromote the current DATABASE_URL" do
        @pg.stub(:args).and_return(['--db', 'HEROKU_POSTGRESQL_RONIN_URL'])
        @pg.stub!(:confirm_command).and_return(true)

        @pg.heroku.should_not_receive(:add_config_vars)
        @pg.should_receive(:abort).with(" !   DATABASE_URL is already set to HEROKU_POSTGRESQL_RONIN_URL.").and_raise(SystemExit)

        lambda { @pg.promote }.should raise_error SystemExit
      end

      it "does not promote DATABASE_URL" do
        @pg.stub(:args).and_return(['--db', 'DATABASE_URL'])
        @pg.stub!(:confirm_command).and_return(true)

        @pg.heroku.should_not_receive(:add_config_vars)
        @pg.should_receive(:abort).with(" !  Promoting DATABASE_URL to DATABASE_URL has no effect.").and_raise(SystemExit)

        lambda { @pg.promote }.should raise_error SystemExit
      end
    end

    context "resolve_db_id" do
      before(:each) do
        @pg.stub!(:config_vars).and_return({
          "DATABASE_URL" => "postgres://cloned_database_url",
          "BRAVO_DATABASE_URL"  => "postgres://bravo_database_url",
          "CLONED_DATABASE_URL" => "postgres://cloned_database_url"
        })
      end

      it "defaults to the current DATABASE_URL" do
        @pg.resolve_db_id(nil, :default => "DATABASE_URL").should == ["CLONED_DATABASE_URL", "postgres://cloned_database_url", true]
      end

      it "should use your specified database URL" do
        @pg.resolve_db_id("BRAVO_DATABASE_URL", :default => "DATABASE_URL").should == ["BRAVO_DATABASE_URL", "postgres://bravo_database_url", false]
      end

      it "should fail if there's no default or URL provided" do
        @pg.should_receive(:abort).with().and_raise(SystemExit)
        lambda { @pg.resolve_db_id(nil) }.should raise_error SystemExit
      end

      it "should fail if there's no default or URL provided" do
        @pg.should_receive(:abort).with().and_raise(SystemExit)
        lambda { @pg.resolve_db_id(nil) }.should raise_error SystemExit
      end
    end

    context "with_heroku_postgresql_database" do
      it "exits if a non HEROKU_POSTGRESQL url is explicitly specified" do
        @pg.stub!(:config_vars).and_return({
          "DATABASE_URL"                => "postgres://shared",
          "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://ronin",
          "HEROKU_POSTGRESQL_IKA_URL"   => "postgres://ika"
        })

        @pg.should_receive(:abort).with(" !  This command is only available for addon databases.").and_raise(SystemExit)
        lambda {
          @pg.with_heroku_postgresql_database { |name, url| }
        }.should raise_error SystemExit
      end

      it "defaults to the db DATABASE_URL references if no args" do
        @pg.stub!(:args).and_return([])
        @pg.stub!(:config_vars).and_return({
          "DATABASE_URL"                => "postgres://ronin",
          "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://ronin",
          "HEROKU_POSTGRESQL_IKA_URL"   => "postgres://ika"
        })

        @pg.with_heroku_postgresql_database do |name, url|
          name.should == "HEROKU_POSTGRESQL_RONIN_URL"
        end
      end

      it "defaults to the first (alphabetical) HEROKU_POSTGRESQL_*_URL if no args and DATABASE_URL isn't helpful" do
        @pg.stub!(:args).and_return([])
        @pg.stub!(:config_vars).and_return({
          "DATABASE_URL"                => "postgres://shared",
          "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://ronin",
          "HEROKU_POSTGRESQL_IKA_URL"   => "postgres://ika"
        })

        @pg.with_heroku_postgresql_database do |name, url|
          name.should == "HEROKU_POSTGRESQL_IKA_URL"
        end
      end
    end
  end
end
