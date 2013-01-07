require "spec_helper"
require "heroku/command/pgbackups"

module Heroku::Command
  describe Pgbackups do
    before do
      @pgbackups = prepare_command(Pgbackups)
      @pgbackups.heroku.stub!(:info).and_return({})

      api.post_app("name" => "example")
      api.put_config_vars(
        "example",
        {
          "DATABASE_URL"            => "postgres://database",
          "HEROKU_POSTGRESQL_IVORY" => "postgres://database",
          "PGBACKUPS_URL"           => "https://ip:password@pgbackups.heroku.com/client"
        }
      )
      @pgbackups.stub :app_attachments => mock_attachments
    end

    let(:mock_attachments) {
      [
        Heroku::Helpers::HerokuPostgresql::Attachment.new({
          'config_var' => 'HEROKU_POSTGRESQL_IVORY',
          'resource' => {'name'  => 'softly-mocking-123',
                         'value' => 'postgres://database',
                         'type'  => 'heroku-postgresql:baku' }})
      ]
    }

    after do
      api.delete_app("example")
    end

    it "requests a pgbackups transfer list for the index command" do
      stub_core
      stub_pgbackups.get_transfers.returns([{
        "created_at"  => "2012-01-01 12:00:00 +0000",
        "started_at"  => "2012-01-01 12:00:01 +0000",
        "from_name"   => "DATABASE",
        "size"        => "1024",
        "progress"    => "dump 2048",
        "to_name"     => "BACKUP",
        "to_url"      => "s3://bucket/userid/b001.dump"
      }])

      stderr, stdout = execute("pgbackups")
      stderr.should == ""
      stdout.should == <<-STDOUT
ID    Backup Time                Status     Size  Database
----  -------------------------  ---------  ----  --------
b001  2012-01-01 12:00:00 +0000  Capturing  1024  DATABASE
STDOUT
    end

    describe "single backup" do
      let(:from_name)  { "FROM_NAME" }
      let(:from_url)   { "postgres://from/bar" }
      let(:attachment) { double('attachment', :display_name => from_name, :url => from_url ) }
      before do
        @pgbackups.stub!(:hpg_resolve).and_return(attachment)
      end

      it "gets the url for the latest backup if nothing is specified" do
        stub_core
        stub_pgbackups.get_latest_backup.returns({"public_url" => "http://latest/backup.dump"})

        old_stdout_isatty = STDOUT.isatty
        $stdout.stub!(:isatty).and_return(true)
        stderr, stdout = execute("pgbackups:url")
        stderr.should == ""
        stdout.should == <<-STDOUT
http://latest/backup.dump
STDOUT
        $stdout.stub!(:isatty).and_return(old_stdout_isatty)
      end

      it "gets the url for the named backup if a name is specified" do
        stub_pgbackups.get_backup.with("b001").returns({"public_url" => "http://latest/backup.dump" })

        old_stdout_isatty = STDOUT.isatty
        $stdout.stub!(:isatty).and_return(true)
        stderr, stdout = execute("pgbackups:url b001")
        stderr.should == ""
        stdout.should == <<-STDOUT
http://latest/backup.dump
STDOUT
        $stdout.stub!(:isatty).and_return(old_stdout_isatty)
      end

      it "should capture a backup when requested" do
        backup_obj = {'to_url' => "s3://bucket/userid/b001.dump"}

        @pgbackups.stub!(:args).and_return([])
        @pgbackups.stub!(:transfer!).with(from_url, from_name, nil, "BACKUP", {:expire => nil}).and_return(backup_obj)
        @pgbackups.stub!(:poll_transfer!).with(backup_obj).and_return(backup_obj)

        @pgbackups.capture
      end

      it "should send expiration flag to client if specified on args" do
        backup_obj = {'to_url' => "s3://bucket/userid/b001.dump"}

        @pgbackups.stub!(:options).and_return({:expire => true})
        @pgbackups.stub!(:transfer!).with(from_url, from_name, nil, "BACKUP", {:expire => true}).and_return(backup_obj)
        @pgbackups.stub!(:poll_transfer!).with(backup_obj).and_return(backup_obj)

        @pgbackups.capture
      end

      it "destroys no backup without a name" do
        stub_core
        stderr, stdout = execute("pgbackups:destroy")
        stderr.should == <<-STDERR
 !    Usage: heroku pgbackups:destroy BACKUP_ID
 !    Must specify BACKUP_ID to destroy.
STDERR
        stdout.should == ""
      end

      it "destroys a backup" do
        stub_core
        stub_pgbackups.get_backup("b001").returns({})
        stub_pgbackups.delete_backup("b001").returns({})

        stderr, stdout = execute("pgbackups:destroy b001")
        stderr.should == ""
        stdout.should == <<-STDOUT
Destroying b001... done
STDOUT
      end

      it "aborts if no database addon is present" do
        api.delete_config_var("example", "DATABASE_URL")
        stub_core
        stderr, stdout = execute("pgbackups:capture")
        stderr.should == <<-STDERR
 !    Your app has no databases.
STDERR
        stdout.should == ""
      end

      context "on errors" do
        def stub_failed_capture(log)
          @backup_obj = {
            "error_at"    => Time.now.to_s,
            "finished_at" => Time.now.to_s,
            "log"         => log,
            'to_url'      => 'postgres://from/bar'
          }
          stub_core
          stub_pgbackups.create_transfer.returns(@backup_obj)
          stub_pgbackups.get_transfer.returns(@backup_obj)

          any_instance_of(Heroku::Command::Pgbackups) do |pgbackups|
            stub(pgbackups).app_attachments.returns(
              mock_attachments
            )
          end
        end

        it 'aborts on a generic error' do
          stub_failed_capture "something generic"
          stderr, stdout = execute("pgbackups:capture")
          stderr.should == <<-STDERR
 !    An error occurred and your backup did not finish.
 !    Please run `heroku logs --ps pgbackups` for details.
STDERR
          stdout.should == <<-STDOUT

HEROKU_POSTGRESQL_IVORY (DATABASE_URL)  ----backup--->  bar

\r\e[0K... 0 -
STDOUT
        end

        it 'aborts and informs when the database isnt up yet' do
          stub_failed_capture 'could not translate host name "ec2-42-42-42-42.compute-1.amazonaws.com" to address: Name or service not known'
          stderr, stdout = execute("pgbackups:capture")
          stderr.should == <<-STDERR
 !    An error occurred and your backup did not finish.
 !    Please run `heroku logs --ps pgbackups` for details.
 !    The database is not yet online. Please try again.
STDERR
          stdout.should == <<-STDOUT

HEROKU_POSTGRESQL_IVORY (DATABASE_URL)  ----backup--->  bar

\r\e[0K... 0 -
STDOUT
        end

        it 'aborts and informs when the credentials are incorrect' do
          stub_failed_capture 'psql: FATAL:  database "randomname" does not exist'
          stderr, stdout = execute("pgbackups:capture")
          stderr.should == <<-STDERR
 !    An error occurred and your backup did not finish.
 !    Please run `heroku logs --ps pgbackups` for details.
 !    The database credentials are incorrect.
STDERR
          stdout.should == <<-STDOUT

HEROKU_POSTGRESQL_IVORY (DATABASE_URL)  ----backup--->  bar

\r\e[0K... 0 -
STDOUT
        end
      end
    end

    context "restore" do
      let(:attachment) { double('attachment', :display_name => 'someconfigvar', :url => 'postgres://fromhost/database') }
      before do
        from_name, from_url = "FROM_NAME", "postgres://fromhost/database"

        @pgbackups_client = mock("pgbackups_client")
        @pgbackups.stub!(:pgbackup_client).and_return(@pgbackups_client)
      end

      it "should receive a confirm_command on restore" do
        @pgbackups_client.stub!(:get_latest_backup).and_return({"to_url" => "s3://bucket/user/bXXX.dump"})

        @pgbackups.should_receive(:confirm_command).and_return(false)
        @pgbackups_client.should_not_receive(:transfer!)

        @pgbackups.restore
      end

      it "aborts if no database addon is present" do
        @pgbackups.should_receive(:hpg_resolve).and_raise(SystemExit)
        lambda { @pgbackups.restore }.should raise_error(SystemExit)
      end

      context "for commands which perform restores" do
        before do
          @backup_obj = {
            "to_name" => "TO_NAME",
            "to_url" => "s3://bucket/userid/bXXX.dump",
            "from_url" => "FROM_NAME",
            "from_name" => "postgres://databasehost/dbname"
          }

          @pgbackups.stub!(:confirm_command).and_return(true)
          @pgbackups_client.should_receive(:create_transfer).and_return(@backup_obj)
          @pgbackups.stub!(:poll_transfer!).and_return(@backup_obj)
        end

        it "should default to the latest backup" do
          @pgbackups.stub(:args).and_return([])
          @pgbackups_client.should_receive(:get_latest_backup).and_return(@backup_obj)
          @pgbackups.restore
        end


        it "should restore the named backup" do
          name = "backupname"
          args = ['DATABASE', name]
          @pgbackups.stub(:args).and_return(args)
          @pgbackups.stub(:shift_argument).and_return(*args)
          @pgbackups.stub(:hpg_resolve).and_return(attachment)
          @pgbackups_client.should_receive(:get_backup).with(name).and_return(@backup_obj)
          @pgbackups.restore
        end

        it "should handle external restores" do
          args = ['db_name_gets_shifted_out_in_resolve_db', 'http://external/file.dump']
          @pgbackups.stub(:args).and_return(args)
          @pgbackups.stub(:shift_argument).and_return(*args)
          @pgbackups.stub(:hpg_resolve).and_return(attachment)
          @pgbackups_client.should_not_receive(:get_backup)
          @pgbackups_client.should_not_receive(:get_latest_backup)
          @pgbackups.restore
        end
      end

      context "on errors" do
        before(:each) do
          @pgbackups_client.stub!(:get_latest_backup).and_return({"to_url" => "s3://bucket/user/bXXX.dump"})
          @pgbackups.stub!(:confirm_command).and_return(true)
        end

        def stub_error_backup_with_log(log)
          @backup_obj = {
            "error_at" => Time.now.to_s,
            "log" => log
          }

          @pgbackups_client.should_receive(:create_transfer).and_return(@backup_obj)
          @pgbackups.stub!(:poll_transfer!).and_return(@backup_obj)
        end

        it 'aborts for a generic error' do
          stub_error_backup_with_log 'something generic'
          @pgbackups.should_receive(:error).with("An error occurred and your restore did not finish.\nPlease run `heroku logs --ps pgbackups` for details.")
          @pgbackups.restore
        end

        it 'aborts and informs for expired s3 urls' do
          stub_error_backup_with_log 'Invalid dump format: /tmp/aDMyoXPrAX/b031.dump: XML  document text'
          @pgbackups.should_receive(:error).with { |message| message.should =~ /backup url is invalid/ }
          @pgbackups.restore
        end
      end
    end
  end
end
