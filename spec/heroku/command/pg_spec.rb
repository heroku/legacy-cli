require "spec_helper"
require "heroku/command/pg"

module Heroku::Command
  describe Pg do
    before do
      @pg = prepare_command(Pg)
      @pg.stub!(:config_vars).and_return({
        "DATABASE_URL" => "postgres://database_url",
        "SHARED_DATABASE_URL" => "postgres://other_database_url",
        "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://database_url",
      })
      @pg.stub!(:args).and_return ["DATABASE_URL"]
      @pg.heroku.stub!(:info).and_return({})

      stub_core.config_vars("myapp").returns({
        "DATABASE_URL" => "postgres://database_url",
        "SHARED_DATABASE_URL" => "postgres://other_database_url",
        "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://database_url"
      })
      stub_core.info("myapp").returns({:database_size => 1024})
    end

    it "resets the app's database if user confirms" do
      stub_pg.reset

      stderr, stdout = execute("pg:reset DATABASE --confirm myapp")
      stderr.should == ""
      stdout.should == <<-STDOUT
----> Resetting HEROKU_POSTGRESQL_RONIN (DATABASE_URL)
\r\e[0KResetting...\r\e[0KResetting... done
STDOUT
    end

    it "doesn't reset the app's database if the user doesn't confirm" do
      # FIXME: how to stub confirm_command
      @pg.stub!(:confirm_command).and_return(false)
      @pg.should_not_receive(:heroku_postgresql_client)
      @pg.reset
    end

    context "index" do
      it "requests the info from the server" do
        stub_pg.get_database.returns(:info => [
          {'name' => "State", 'value' => "available"},
          {'name' => "whatever", 'values' => ['one', 'eh']}
        ])

        stderr, stdout = execute("pg")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== HEROKU_POSTGRESQL_RONIN (DATABASE_URL)
State        available
whatever     one
             eh
=== SHARED_DATABASE
Data Size    1k
STDOUT
      end
    end

    context "info" do
      it "requests the info from the server" do
        stub_pg.get_database.returns(:info => [
          {'name' => "State", 'value' => "available"},
          {'name' => "whatever", 'values' => ['one', 'eh']}
        ])

        stderr, stdout = execute("pg:info DATABASE")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== HEROKU_POSTGRESQL_RONIN (DATABASE_URL)
State        available
whatever     one
             eh
STDOUT
      end
    end

    context "promotion" do
      it "promotes the specified database" do
        stub_core.add_config_vars("myapp", {"DATABASE_URL" => "postgres://other_database_url"})

        stderr, stdout = execute("pg:promote SHARED_DATABASE --confirm myapp")
        stderr.should == ""
        stdout.should == <<-STDOUT
\r\e[0K-----> Promoting SHARED_DATABASE to DATABASE_URL...\r\e[0K-----> Promoting SHARED_DATABASE to DATABASE_URL... done
STDOUT
      end

      it "promotes the specified database url case-sensitively" do
        stub_core.add_config_vars("myapp", {"DATABASE_URL" => "postgres://john:S3nsit1ve@my.example.com/db_name"})

        stderr, stdout = execute("pg:promote postgres://john:S3nsit1ve@my.example.com/db_name --confirm=myapp")
        stderr.should == ""
        stdout.should == <<-STDOUT
\r\e[0K-----> Promoting Database on my.example.com to DATABASE_URL...\r\e[0K-----> Promoting Database on my.example.com to DATABASE_URL... done
STDOUT
      end

      it "fails if no database is specified" do
        stderr, stdout = execute("pg:promote")
        stderr.should == <<-STDERR
 !    Usage: heroku pg:promote <DATABASE>
STDERR
        # FIXME: sometimes contains 'failed'
        #stdout.should == ""
      end

      it "does not repromote the current DATABASE_URL" do
        stderr, stdout = execute("pg:promote HEROKU_POSTGRESQL_RONIN")
        stderr.should == <<-STDERR
 !    DATABASE_URL is already set to HEROKU_POSTGRESQL_RONIN
STDERR
        # FIXME: sometimes contains 'failed'
        #stdout.should == ""
      end

      it "does not promote DATABASE_URL" do
        stderr, stdout = execute("pg:promote DATABASE_URL")
        stderr.should == <<-STDERR
 !    DATABASE_URL is already set to HEROKU_POSTGRESQL_RONIN
STDERR
        # FIXME: sometimes contains 'failed'
        #stdout.should == ""
      end
    end
  end
end
