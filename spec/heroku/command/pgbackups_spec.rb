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
  end
end
