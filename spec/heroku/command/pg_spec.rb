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
          {"name" => "Conn Info", "values"=>["\"host=ec2-012-34-567-890.compute-1.amazonaws.com", "port=5432 dbname=abcdefghijklmn", "user=abcdefghijklm sslmode=require", "password=abcdefghijklmnopqrstuvwxyz0\""]},
          {"name"=>"Data Size", "values"=>["1 MB"]},
          {"name"=>"Created", "values"=>["2011-12-13 00:00 UTC"]},
          {"name"=>"Followers", "values"=>[], "resolve_db_name"=>true},
          {"name"=>"Forks", "values"=>[], "resolve_db_name"=>true},
          {"name"=>"Maintenance", "values"=>["not required"]},
          {"name"=>"PG Version", "values"=>["9.0.0"]},
          {"name"=>"Plan", "values"=>["Ronin"]},
          {"name"=>"Status", "values"=>["available"]},
          {"name"=>"Tables", "values"=>[1]}
        ])

        stderr, stdout = execute("pg")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== HEROKU_POSTGRESQL_RONIN
Conn Info:   
  "host=ec2-012-34-567-890.compute-1.amazonaws.com
  port=5432 dbname=abcdefghijklmn
  user=abcdefghijklm sslmode=require
  password=abcdefghijklmnopqrstuvwxyz0"

Created:     2011-12-13 00:00 UTC
Data Size:   1 MB
Maintenance: not required
PG Version:  9.0.0
Plan:        Ronin
Status:      available
Tables:      1

STDOUT
      end
    end

    context "info" do
      it "requests the info from the server" do
        stub_pg.get_database.returns(:info => [
          {"name" => "Conn Info", "values"=>["\"host=ec2-012-34-567-890.compute-1.amazonaws.com", "port=5432 dbname=abcdefghijklmn", "user=abcdefghijklm sslmode=require", "password=abcdefghijklmnopqrstuvwxyz0\""]},
          {"name"=>"Data Size", "values"=>["1 MB"]},
          {"name"=>"Created", "values"=>["2011-12-13 00:00 UTC"]},
          {"name"=>"Followers", "values"=>[], "resolve_db_name"=>true},
          {"name"=>"Forks", "values"=>[], "resolve_db_name"=>true},
          {"name"=>"Maintenance", "values"=>["not required"]},
          {"name"=>"PG Version", "values"=>["9.0.0"]},
          {"name"=>"Plan", "values"=>["Ronin"]},
          {"name"=>"Status", "values"=>["available"]},
          {"name"=>"Tables", "values"=>[1]}
        ])

        stderr, stdout = execute("pg:info RONIN")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== HEROKU_POSTGRESQL_RONIN
Conn Info:   
  "host=ec2-012-34-567-890.compute-1.amazonaws.com
  port=5432 dbname=abcdefghijklmn
  user=abcdefghijklm sslmode=require
  password=abcdefghijklmnopqrstuvwxyz0"

Created:     2011-12-13 00:00 UTC
Data Size:   1 MB
Maintenance: not required
PG Version:  9.0.0
Plan:        Ronin
Status:      available
Tables:      1

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
Promoting custom URL to DATABASE_URL... done
STDOUT
      end

      it "fails if no database is specified" do
        stderr, stdout = execute("pg:promote")
        stderr.should == <<-STDERR
 !    Usage: heroku pg:promote DATABASE
STDERR
        stdout.should == ""
      end
    end
  end
end
