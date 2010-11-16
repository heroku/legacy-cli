require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Pgbackups do
    before do
      @pgbackups = prepare_command(Pgbackups)
      @pgbackups.stub!(:config_vars).and_return({
        "PGBACKUPS_URL" => "https://ip:password@pgbackups.heroku.com/client"
      })
      @pgbackups.heroku.stub!(:info).and_return({})
    end

    it "requests a pgbackups transfer list for the index command" do
      fake_client = mock("pgbackups_client")
      fake_client.should_receive(:get_transfers).and_return([])
      @pgbackups.should_receive(:pgbackup_client).with.and_return(fake_client)

      @pgbackups.index
    end

    describe "single backup" do
      it "gets the url for the latest backup if nothing is specified" do
        latest_backup_url= "http://latest/backup.dump"
        fake_client = mock("pgbackups_client")
        fake_client.should_receive(:get_latest_backup).and_return({'public_url' => latest_backup_url })
        @pgbackups.should_receive(:pgbackup_client).and_return(fake_client)
        @pgbackups.should_receive(:display).with(latest_backup_url)

        @pgbackups.url
      end

      it "gets the url for the named backup if a name is specified" do
        backup_name = "b001"
        named_url = "http://latest/backup.dump"
        @pgbackups.stub!(:args).and_return([backup_name])

        fake_client = mock("pgbackups_client")
        fake_client.should_receive(:get_backup).with(backup_name).and_return({'public_url' => named_url })
        @pgbackups.should_receive(:pgbackup_client).and_return(fake_client)

        @pgbackups.should_receive(:display).with(named_url)

        @pgbackups.url
      end

      it "should capture a backup when requested" do
        from_url = "postgres://from/bar"
        from_name = "FROM_NAME"
        backup_obj = {'to_url' => "s3://bucket/userid/b001.dump"}

        @pgbackups.stub!(:resolve_db_id).and_return([from_name, from_url])
        @pgbackups.stub!(:poll_transfer!).with(backup_obj).and_return(backup_obj)

        fake_client = mock("pgbackups_client")
        fake_client.should_receive(:create_transfer).with(from_url, from_name, nil, "BACKUP", {}).and_return(backup_obj)
        @pgbackups.should_receive(:pgbackup_client).and_return(fake_client)

        @pgbackups.capture
      end

      it "should send expiration flag to client if specified on args" do
        from_url = "postgres://from/bar"
        from_name = "FROM_NAME"
        backup_obj = {'to_url' => "s3://bucket/userid/b001.dump"}

        @pgbackups.stub!(:resolve_db_id).and_return([from_name, from_url])
        @pgbackups.stub!(:poll_transfer!).with(backup_obj).and_return(backup_obj)
        @pgbackups.stub!(:args).and_return(['--expire'])

        fake_client = mock("pgbackups_client")
        fake_client.should_receive(:create_transfer).with(from_url, from_name, nil, "BACKUP", {:expire => true}).and_return(backup_obj)
        @pgbackups.should_receive(:pgbackup_client).and_return(fake_client)

        @pgbackups.capture
      end

      it "destroys no backup without a name" do
        @pgbackups.stub!(:args).and_return([])

        fake_client = mock("pgbackups_client")
        fake_client.should_not_receive(:delete_backup)
        @pgbackups.should_not_receive(:pgbackup_client).and_return(fake_client)

        @pgbackups.stub!(:abort).and_raise(SystemExit)

        lambda { @pgbackups.destroy }.should raise_error SystemExit
      end

      it "destroys a backup on request if confirmed" do
        name = "b001"
        @pgbackups.stub!(:args).and_return([name])

        fake_client = mock("pgbackups_client")
        fake_client.should_receive(:get_backup).with(name).and_return({})
        fake_client.should_receive(:delete_backup).with(name).and_return({})
        @pgbackups.should_receive(:pgbackup_client).and_return(fake_client, fake_client)

        @pgbackups.destroy
      end

    end
    context "restore" do
      before do
        from_url = "postgres://fromhost/database"
        from_name = "FROM_NAME"
        @pgbackups.stub!(:resolve_db_id).and_return([from_name, from_url])

        @pgbackups_client = mock("pgbackups_client")
        @pgbackups.stub!(:pgbackup_client).and_return(@pgbackups_client)
      end

      after do
        @pgbackups.restore
      end

      it "should receive a confirm_command on restore" do
        @pgbackups_client.stub!(:get_latest_backup).and_return({"to_url" => "s3://bucket/user/bXXX.dump"})

        @pgbackups.should_receive(:confirm_command).and_return(false)
        @pgbackups_client.should_not_receive(:transfer!)
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
        end
        it "should restore the named backup" do
          name = "backupname"
          @pgbackups.stub(:args).and_return([name])
          @pgbackups_client.should_receive(:get_backup).with(name).and_return(@backup_obj)
        end
        it "should handle external restores" do
          @pgbackups.stub(:args).and_return(["http://external/file.dump"])
          @pgbackups_client.should_not_receive(:get_backup)
          @pgbackups_client.should_not_receive(:get_latest_backup)
        end
      end
    end
  end
end
