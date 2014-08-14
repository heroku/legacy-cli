require "spec_helper"
require "heroku/command/pgbackups"

module Heroku::Command
  describe Pgbackups, 'with no databases' do
    it "aborts if no database addon is present" do
        api.post_app("name" => "example")
        stub_core
        stderr, stdout = execute("pgbackups:capture")
        expect(stderr).to eq <<-STDERR
 !    Your app has no databases.
STDERR
        expect(stdout).to eq("")
        api.delete_app("example")
    end
  end

  describe Pgbackups do
    before do
      @pgbackups = prepare_command(Pgbackups)
      allow(@pgbackups.heroku).to receive(:info).and_return({})

      api.post_app("name" => "example")
      api.put_config_vars(
        "example",
        {
          "DATABASE_URL"            => "postgres://database",
          "HEROKU_POSTGRESQL_IVORY" => "postgres://database",
          "PGBACKUPS_URL"           => "https://ip:password@pgbackups.heroku.com/client"
        }
      )
      any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver) do |pg|
        stub(pg).app_attachments.returns(mock_attachments)
        stub(pg).api.returns(api)
      end
    end

    let(:mock_attachments) {
      [
        Heroku::Helpers::HerokuPostgresql::Attachment.new({
          'app' => {'name' => 'sushi'},
          'name' => 'HEROKU_POSTGRESQL_IVORY',
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
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
ID    Backup Time                Status     Size  Database
----  -------------------------  ---------  ----  --------
b001  2012-01-01 12:00:01 +0000  Capturing  1024  DATABASE
STDOUT
    end

    describe "single backup" do
      let(:from_name)  { "FROM_NAME" }
      let(:from_url)   { "postgres://from/bar" }
      let(:attachment) { double('attachment', :display_name => from_name, :url => from_url ) }
      before do
        allow(@pgbackups).to receive(:resolve).and_return(attachment)
      end

      it "gets the url for the latest backup if nothing is specified" do
        stub_core
        stub_pgbackups.get_latest_backup.returns({"public_url" => "http://latest/backup.dump"})

        old_stdout_isatty = STDOUT.isatty
        allow($stdout).to receive(:isatty).and_return(true)
        stderr, stdout = execute("pgbackups:url")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
http://latest/backup.dump
STDOUT
        allow($stdout).to receive(:isatty).and_return(old_stdout_isatty)
      end

      it "gets the url for the named backup if a name is specified" do
        stub_pgbackups.get_backup.with("b001").returns({"public_url" => "http://latest/backup.dump" })

        old_stdout_isatty = STDOUT.isatty
        allow($stdout).to receive(:isatty).and_return(true)
        stderr, stdout = execute("pgbackups:url b001")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
http://latest/backup.dump
STDOUT
        allow($stdout).to receive(:isatty).and_return(old_stdout_isatty)
      end

      it "should capture a backup when requested" do
        backup_obj = {'to_url' => "s3://bucket/userid/b001.dump"}

        allow(@pgbackups).to receive(:args).and_return([])
        allow(@pgbackups).to receive(:transfer!).with(from_url, from_name, nil, "BACKUP", {:expire => nil}).and_return(backup_obj)
        allow(@pgbackups).to receive(:poll_transfer!).with(backup_obj).and_return(backup_obj)

        @pgbackups.capture
      end

      it "should send expiration flag to client if specified on args" do
        backup_obj = {'to_url' => "s3://bucket/userid/b001.dump"}

        allow(@pgbackups).to receive(:options).and_return({:expire => true})
        allow(@pgbackups).to receive(:transfer!).with(from_url, from_name, nil, "BACKUP", {:expire => true}).and_return(backup_obj)
        allow(@pgbackups).to receive(:poll_transfer!).with(backup_obj).and_return(backup_obj)

        @pgbackups.capture
      end

      it "destroys no backup without a name" do
        stub_core
        stderr, stdout = execute("pgbackups:destroy")
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku pgbackups:destroy BACKUP_ID
 !    Must specify BACKUP_ID to destroy.
STDERR
        expect(stdout).to eq("")
      end

      it "destroys a backup" do
        stub_core
        stub_pgbackups.get_backup("b001").returns({})
        stub_pgbackups.delete_backup("b001").returns({})

        stderr, stdout = execute("pgbackups:destroy b001")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Destroying b001... done
STDOUT
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
          expect(stderr).to eq <<-STDERR
 !    An error occurred and your backup did not finish.
 !    Please run `heroku logs --ps pgbackups` for details.
STDERR
          expect(stdout).to eq <<-STDOUT

HEROKU_POSTGRESQL_IVORY (DATABASE_URL)  ----backup--->  bar

\r\e[0K... 0 -
STDOUT
        end

        it 'aborts and informs when the database isnt up yet' do
          stub_failed_capture 'could not translate host name "ec2-42-42-42-42.compute-1.amazonaws.com" to address: Name or service not known'
          stderr, stdout = execute("pgbackups:capture")
          expect(stderr).to eq <<-STDERR
 !    An error occurred and your backup did not finish.
 !    Please run `heroku logs --ps pgbackups` for details.
 !    The database is not yet online. Please try again.
STDERR
          expect(stdout).to eq <<-STDOUT

HEROKU_POSTGRESQL_IVORY (DATABASE_URL)  ----backup--->  bar

\r\e[0K... 0 -
STDOUT
        end

        it 'aborts and informs when the credentials are incorrect' do
          stub_failed_capture 'psql: FATAL:  database "randomname" does not exist'
          stderr, stdout = execute("pgbackups:capture")
          expect(stderr).to eq <<-STDERR
 !    An error occurred and your backup did not finish.
 !    Please run `heroku logs --ps pgbackups` for details.
 !    The database credentials are incorrect.
STDERR
          expect(stdout).to eq <<-STDOUT

HEROKU_POSTGRESQL_IVORY (DATABASE_URL)  ----backup--->  bar

\r\e[0K... 0 -
STDOUT
        end
      end
    end

    context "restore" do
      let(:attachment) { double('attachment', :display_name => 'someconfigvar', :url => 'postgres://fromhost/database') }
      before do
        @pgbackups_client = double("pgbackups_client")
        allow(@pgbackups).to receive(:pgbackup_client).and_return(@pgbackups_client)
      end

      it "should receive a confirm_command on restore" do
        allow(@pgbackups_client).to receive(:get_latest_backup) { {"to_url" => "s3://bucket/user/bXXX.dump"} }

        expect(@pgbackups).to receive(:confirm_command).and_return(false)
        expect(@pgbackups_client).not_to receive(:transfer!)

        @pgbackups.restore
      end

      it "aborts if no database addon is present" do
        expect(@pgbackups).to receive(:resolve).and_raise(SystemExit)
        expect { @pgbackups.restore }.to raise_error(SystemExit)
      end

      context "for commands which perform restores" do
        before do
          @backup_obj = {
            "to_name" => "TO_NAME",
            "to_url" => "s3://bucket/userid/bXXX.dump",
            "from_url" => "FROM_NAME",
            "from_name" => "postgres://databasehost/dbname"
          }

          allow(@pgbackups).to receive(:confirm_command).and_return(true)
          expect(@pgbackups_client).to receive(:create_transfer).and_return(@backup_obj)
          allow(@pgbackups).to receive(:poll_transfer!).and_return(@backup_obj)
        end

        it "should default to the latest backup" do
          allow(@pgbackups).to receive(:args).and_return([])
          mock(@pgbackups_client).get_latest_backup.returns(@backup_obj)
          @pgbackups.restore
        end


        it "should restore the named backup" do
          name = "backupname"
          args = ['DATABASE', name]
          allow(@pgbackups).to receive(:args).and_return(args)
          allow(@pgbackups).to receive(:shift_argument).and_return(*args)
          allow(@pgbackups).to receive(:resolve).and_return(attachment)
          mock(@pgbackups_client).get_backup.with(name).returns(@backup_obj)
          @pgbackups.restore
        end

        it "should handle external restores" do
          args = ['db_name_gets_shifted_out_in_resolve_db', 'http://external/file.dump']
          allow(@pgbackups).to receive(:args).and_return(args)
          allow(@pgbackups).to receive(:shift_argument).and_return(*args)
          allow(@pgbackups).to receive(:resolve).and_return(attachment)
          expect(@pgbackups_client).not_to receive(:get_backup)
          expect(@pgbackups_client).not_to receive(:get_latest_backup)
          @pgbackups.restore
        end
      end

      context "on errors" do
        before(:each) do
          allow(@pgbackups_client).to receive(:get_latest_backup).and_return("to_url" => "s3://bucket/user/bXXX.dump")
          allow(@pgbackups).to receive(:confirm_command).and_return(true)
        end

        def stub_error_backup_with_log(log)
          @backup_obj = {
            "error_at" => Time.now.to_s,
            "log" => log
          }

          expect(@pgbackups_client).to receive(:create_transfer) { @backup_obj }
          allow(@pgbackups).to receive(:poll_transfer!) { @backup_obj }
        end

        it 'aborts for a generic error' do
          stub_error_backup_with_log 'something generic'
          expect(@pgbackups).to receive(:error).with("An error occurred and your restore did not finish.\nPlease run `heroku logs --ps pgbackups` for details.")
          @pgbackups.restore
        end

        it 'aborts and informs for expired s3 urls' do
          stub_error_backup_with_log 'Invalid dump format: /tmp/aDMyoXPrAX/b031.dump: XML  document text'
          expect(@pgbackups).to receive(:error).with(/backup url is invalid/)
          @pgbackups.restore
        end
      end
    end
  end
end
