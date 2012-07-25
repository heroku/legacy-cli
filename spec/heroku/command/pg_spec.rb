require "spec_helper"
require "heroku/command/pg"

module Heroku::Command
  describe Pg do
    before do
      stub_core

      api.post_app "name" => "myapp"
      api.put_config_vars "myapp", {
        "DATABASE_URL" => "postgres://database_url",
        "SHARED_DATABASE_URL" => "postgres://other_database_url",
        "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://ronin_database_url"
      }
    end

    after do
      api.delete_app "myapp"
    end

    it "resets the app's database if user confirms" do
      stub_pg.reset

      stderr, stdout = execute("pg:reset RONIN --confirm myapp")
      stderr.should == ""
      stdout.should == <<-STDOUT
Resetting HEROKU_POSTGRESQL_RONIN... done
STDOUT
    end

    it "resets shared databases" do
      Heroku::Client.any_instance.should_receive(:database_reset).with('myapp')

      stderr, stdout = execute("pg:reset SHARED_DATABASE --confirm myapp")
      stderr.should == ''
      stdout.should == <<-STDOUT
Resetting SHARED_DATABASE... done
STDOUT
    end

    it "doesn't reset the app's database if the user doesn't confirm" do
      stub_pg.reset

      stderr, stdout = execute("pg:reset RONIN")
      stderr.should == <<-STDERR
 !    Confirmation did not match myapp. Aborted.
STDERR
      stdout.should == "
 !    WARNING: Destructive Action
 !    This command will affect the app: myapp
 !    To proceed, type \"myapp\" or re-run this command with --confirm myapp

> "
    end

    context "index" do
      it "requests the info from the server" do
        stub_pg.get_database.returns(:info => [
          {"name"=>"Plan", "values"=>["Ronin"]},
          {"name"=>"Status", "values"=>["available"]},
          {"name"=>"Data Size", "values"=>["1 MB"]},
          {"name"=>"Tables", "values"=>[1]},
          {"name"=>"PG Version", "values"=>["9.1.4"]},
          {"name"=>"Fork/Follow", "values"=>["Available"]},
          {"name"=>"Created", "values"=>["2011-12-13 00:00 UTC"]},
          {"name"=>"Conn Info", "values"=>["[Deprecated] Please use `heroku pg:credentials HEROKU_POSTGRESQL_RONIN` to view connection info"]},
          {"name"=>"Maintenance", "values"=>["not required"]}
        ])

        stderr, stdout = execute("pg")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== HEROKU_POSTGRESQL_RONIN
Plan:        Ronin
Status:      available
Data Size:   1 MB
Tables:      1
PG Version:  9.1.4
Fork/Follow: Available
Created:     2011-12-13 00:00 UTC
Conn Info:   [Deprecated] Please use `heroku pg:credentials HEROKU_POSTGRESQL_RONIN` to view connection info
Maintenance: not required

=== SHARED_DATABASE
Data Size: (empty)

STDOUT
      end
    end

    context "info" do
      it "requests the info from the server" do
        stub_pg.get_database.returns(:info => [
          {"name"=>"Plan", "values"=>["Ronin"]},
          {"name"=>"Status", "values"=>["available"]},
          {"name"=>"Data Size", "values"=>["1 MB"]},
          {"name"=>"Tables", "values"=>[1]},
          {"name"=>"PG Version", "values"=>["9.1.4"]},
          {"name"=>"Fork/Follow", "values"=>["Available"]},
          {"name"=>"Forked From", "values"=>["postgres://username:password@postgreshost.com:5432/database_name"], "resolve_db_name" => "true"},
          {"name"=>"Created", "values"=>["2011-12-13 00:00 UTC"]},
          {"name"=>"Conn Info", "values"=>["[Deprecated] Please use `heroku pg:credentials HEROKU_POSTGRESQL_RONIN` to view connection info"]},
          {"name"=>"Maintenance", "values"=>["not required"]}
        ])

        stderr, stdout = execute("pg:info RONIN")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== HEROKU_POSTGRESQL_RONIN
Plan:        Ronin
Status:      available
Data Size:   1 MB
Tables:      1
PG Version:  9.1.4
Fork/Follow: Available
Forked From: Database on postgreshost.com:5432/database_name
Created:     2011-12-13 00:00 UTC
Conn Info:   [Deprecated] Please use `heroku pg:credentials HEROKU_POSTGRESQL_RONIN` to view connection info
Maintenance: not required

STDOUT
      end
    end

    context "promotion" do
      it "promotes the specified database" do
        stderr, stdout = execute("pg:promote RONIN --confirm myapp")
        stderr.should == ""
        stdout.should == <<-STDOUT
Promoting HEROKU_POSTGRESQL_RONIN to DATABASE_URL... done
STDOUT
        api.get_config_vars("myapp").body["DATABASE_URL"].should == "postgres://ronin_database_url"
      end

      it "promotes the specified database url case-sensitively" do
        stderr, stdout = execute("pg:promote postgres://john:S3nsit1ve@my.example.com/db_name --confirm=myapp")
        stderr.should == ""
        stdout.should == <<-STDOUT
Promoting Custom URL to DATABASE_URL... done
STDOUT
      end

      it "fails if no database is specified" do
        stderr, stdout = execute("pg:promote")
        stderr.should == <<-STDERR
 !    Usage: heroku pg:promote DATABASE
 !    Must specify DATABASE to promote.
STDERR
        stdout.should == ""
      end
    end

    context "credential resets" do
      before do
        api.put_config_vars "myapp", {
          "DATABASE_URL" => "postgres:///to_reset_credentials",
          "HEROKU_POSTGRESQL_RESETME_URL" => "postgres:///to_reset_credentials"
        }
      end

      it "resets credentials and promotes to DATABASE_URL if it's the main DB" do
        stub_pg.rotate_credentials
        stderr, stdout = execute("pg:credentials resetme --reset")
        stderr.should be_empty
        stdout.should == <<-STDOUT
Resetting credentials for HEROKU_POSTGRESQL_RESETME (DATABASE_URL)... done
Promoting HEROKU_POSTGRESQL_RESETME (DATABASE_URL)... done
STDOUT
      end

      it "does not update DATABASE_URL if it's not the main db" do
        stub_pg.rotate_credentials
        api.put_config_vars "myapp", {
          "DATABASE_URL" => "postgres://to_reset_credentials",
          "HEROKU_POSTGRESQL_RESETME_URL" => "postgres://something_else"
        }
        stderr, stdout = execute("pg:credentials resetme --reset")
        stderr.should be_empty
        stdout.should_not include("Promoting")
      end

    end

    context "unfollow" do
      before do
        api.put_config_vars "myapp", {
          "DATABASE_URL" => "postgres://database_url",
          "SHARED_DATABASE_URL" => "postgres://other_database_url",
          "HEROKU_POSTGRESQL_RONIN_URL" => "postgres://ronin_database_url",
          "HEROKU_POSTGRESQL_OTHER_URL" => "postgres://other_database_url"
        }
      end

      it "sends request to unfollow" do
        hpg_client = double('Heroku::Client::HerokuPostgresql')
        Heroku::Client::HerokuPostgresql.should_receive(:new).twice.with('postgres://other_database_url').and_return(hpg_client)
        hpg_client.should_receive(:unfollow)
        hpg_client.should_receive(:get_database).and_return(
          :following => 'postgresql://user:pass@roninhost/database',
          :info => [
            {"name"=>"Plan", "values"=>["Ronin"]},
            {"name"=>"Status", "values"=>["available"]},
            {"name"=>"Data Size", "values"=>["1 MB"]},
            {"name"=>"Tables", "values"=>[1]},
            {"name"=>"PG Version", "values"=>["9.1.4"]},
            {"name"=>"Fork/Follow", "values"=>["Available"]},
            {"name"=>"Created", "values"=>["2011-12-13 00:00 UTC"]},
            {"name"=>"Conn Info", "values"=>["[Deprecated] Please use `heroku pg:credentials HEROKU_POSTGRESQL_RONIN` to view connection info"]},
            {"name"=>"Maintenance", "values"=>["not required"]}
          ]
        )
        stderr, stdout = execute("pg:unfollow HEROKU_POSTGRESQL_OTHER --confirm myapp")
        stderr.should == ""
        stdout.should == <<-STDOUT
 !    HEROKU_POSTGRESQL_OTHER will become writable and no longer
 !    follow Database on roninhost:5432/database. This cannot be undone.
Unfollowing HEROKU_POSTGRESQL_OTHER... done
STDOUT
      end
    end

  end
end
