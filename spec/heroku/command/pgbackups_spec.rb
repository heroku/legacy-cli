require "spec_helper"
require "heroku/command/pgbackups"

module Heroku::Command
  describe Pgbackups, 'is removed' do
    it "does not list" do
        stderr, stdout = execute("pgbackups")
        expect(stderr).to eq <<-STDERR
 !    'heroku pgbackups' has been removed.
 !    Please see 'heroku pg:backups' instead.
 !    More Information: https://devcenter.heroku.com/articles/heroku-postgres-backups
STDERR
        expect(stdout).to eq("")
    end

    context "wait" do
      before do
        @unfinished_backup_obj = {
            "finished_at" => nil,
        }
        @finished_backup_obj = {
            "finished_at" => Time.now.to_s,
        }
        @pgbackups_client = mock("pgbackups_client")
        @pgbackups.stub!(:pgbackup_client).and_return(@pgbackups_client)
      end
      it "waits for all transfers to finish" do
        @pgbackups_client.stub(:get_transfers).and_return([@unfinished_backup_obj],[@unfinished_backup_obj,@finished_backup_obj],[@finished_backup_obj,@finished_backup_obj])
        @pgbackups.should_receive(:sleep).twice
        @pgbackups.wait
      end

    end

  end
end
