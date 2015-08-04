require "spec_helper"
require "heroku/command/pg"
require "heroku/command/pg_backups"

module Heroku::Command
  describe Pg do
    let(:ivory_url) { 'postgres:///database_url' }
    let(:green_url) { 'postgres:///green_database_url' }
    let(:red_url)   { 'postgres:///red_database_url' }

    let(:teal_url)  { 'postgres:///teal_database_url' }

    let(:example_attachments) do
      [
          Heroku::Helpers::HerokuPostgresql::Attachment.new({
            'app' => {'name' => 'example'},
            'name' => 'HEROKU_POSTGRESQL_IVORY',
            'config_var' => 'HEROKU_POSTGRESQL_IVORY_URL',
            'resource' => {'name'  => 'loudly-yelling-1232',
                           'value' => ivory_url,
                           'type'  => 'heroku-postgresql:standard-0' }}),
          Heroku::Helpers::HerokuPostgresql::Attachment.new({
            'app' => {'name' => 'example'},
            'name' => 'HEROKU_POSTGRESQL_GREEN',
            'config_var' => 'HEROKU_POSTGRESQL_GREEN_URL',
            'resource' => {'name'  => 'softly-mocking-123',
                           'value' => green_url,
                           'type'  => 'heroku-postgresql:standard-0' }}),
          Heroku::Helpers::HerokuPostgresql::Attachment.new({
            'app' => {'name' => 'example'},
            'name' => 'HEROKU_POSTGRESQL_RED',
            'config_var' => 'HEROKU_POSTGRESQL_RED_URL',
            'resource' => {'name'  => 'whatever-something-2323',
                           'value' => red_url,
                           'type'  => 'heroku-postgresql:standard-0' }})
      ]
    end

    let(:aux_example_attachments) do
      [
          Heroku::Helpers::HerokuPostgresql::Attachment.new({
            'app' => {'name' => 'aux-example'},
            'name' => 'HEROKU_POSTGRESQL_TEAL',
            'config_var' => 'HEROKU_POSTGRESQL_TEAL_URL',
            'resource' => {'name'  => 'loudly-yelling-1232',
                           'value' => teal_url,
                           'type'  => 'heroku-postgresql:standard-0' }})
      ]
    end

    before do
      stub_core

      api.post_app "name" => "example"
      api.put_config_vars "example", {
        "DATABASE_URL" => "postgres://database_url",
        "HEROKU_POSTGRESQL_IVORY_URL" => ivory_url,
        "HEROKU_POSTGRESQL_GREEN_URL" => green_url,
        "HEROKU_POSTGRESQL_RED_URL" => red_url,
      }

      api.post_app "name" => "aux-example"
      api.put_config_vars "aux-example", {
        "DATABASE_URL" => "postgres://database_url",
        "HEROKU_POSTGRESQL_TEAL_URL" => teal_url
      }
    end

    after do
      api.delete_app "aux-example"
      api.delete_app "example"
    end

    describe "heroku pg:copy" do
      let(:copy_info) do
        { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
         :from_type => 'pg_dump', :to_type => 'pg_restore',
         :started_at => Time.now, :finished_at => Time.now,
         :processed_bytes => 42, :succeeded => true }
      end

      before do
        # hideous hack because we can't do dependency injection
        orig_new = Heroku::Helpers::HerokuPostgresql::Resolver.method(:new)
        allow(Heroku::Helpers::HerokuPostgresql::Resolver).to receive(:new) do |app_name, api|
          resolver = orig_new.call(app_name, api)
          allow(resolver).to receive(:app_attachments) do
            if resolver.app_name == 'example'
              example_attachments
            else
              aux_example_attachments
            end
          end
          resolver
        end
      end

      it "copies data from one database to another" do
        stub_pg.pg_copy('IVORY', ivory_url, 'RED', red_url).returns(copy_info)
        stub_pgapp.transfers_get.returns(copy_info)

        stderr, stdout = execute("pg:copy ivory red --confirm example")
        expect(stderr).to be_empty
        expect(stdout).to match(/Copy completed/)
      end

      it "does not copy without confirmation" do
        stderr, stdout = execute("pg:copy ivory red")
        expect(stderr).to match(/Confirmation did not match example. Aborted./)
        expect(stdout).to match(/WARNING: Destructive Action/)
        expect(stdout).to match(/This command will affect the app: example/)
        expect(stdout).to match(/To proceed, type "example" or re-run this command with --confirm example/)
      end

      it "copies across apps" do
        stub_pg.pg_copy('TEAL', teal_url, 'RED', red_url).returns(copy_info)
        stub_pgapp.transfers_get.returns(copy_info)

        stderr, stdout = execute("pg:copy aux-example::teal red --confirm example")
        expect(stderr).to be_empty
        expect(stdout).to match(/Copy completed/)
      end
    end

    describe "heroku pg:backups schedules" do
      let(:schedules) do
        [ { name: 'HEROKU_POSTGRESQL_GREEN_URL',
            uuid: 'ffffffff-ffff-ffff-ffff-ffffffffffff',
            hour: 4, timezone: 'US/Pacific' },
          { name: 'DATABASE_URL',
            uuid: 'ffffffff-ffff-ffff-ffff-fffffffffffe',
            hour: 20, timezone: 'UTC'  } ]
      end

      it "lists the existing schedules" do
        allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver)
          .to receive(:app_attachments).and_return(example_attachments)
        stub_pg.schedules.returns(schedules)
        stderr, stdout = execute("pg:backups schedules")
        expect(stderr).to be_empty
        expect(stdout).to eq(<<-EOF)
=== Backup Schedules
HEROKU_POSTGRESQL_GREEN_URL: daily at 4:00 (US/Pacific)
DATABASE_URL: daily at 20:00 (UTC)
EOF
      end

      it "reports there are no schedules when none exist" do
        allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver)
          .to receive(:app_attachments).and_return(example_attachments)
        stub_pg.schedules.returns([])
        stderr, stdout = execute("pg:backups schedules")
        expect(stderr).to be_empty
        expect(stdout).to match(/No backup schedules found/)
      end

      it "reports there are no databases when the app has none" do
        allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver)
          .to receive(:app_attachments).and_return([])
        stderr, stdout = execute("pg:backups schedules")
        expect(stderr).to match(/example has no heroku-postgresql databases/)
        expect(stdout).to be_empty
      end
    end

    describe "heroku pg:backups schedule" do
      before do
        allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver)
          .to receive(:app_attachments).and_return(example_attachments)
      end

      it "schedules the requested database at the specified time" do
        stub_pg.schedule({ hour: '07', timezone: 'UTC',
                           schedule_name: 'HEROKU_POSTGRESQL_RED_URL' })
        stderr, stdout = execute("pg:backups schedule RED --at '07:00 UTC' --app example")
        expect(stderr).to be_empty
        expect(stdout).to match(/Scheduled automatic daily backups/)
      end

      it "finds the right database when there are similarly-named databases" do
        additional_attachment = Heroku::Helpers::HerokuPostgresql::Attachment
                               .new({
                                      'app' => {'name' => 'example'},
                                      'name' => 'ALSO_HEROKU_POSTGRESQL_IVORY',
                                      'config_var' => 'ALSO_HEROKU_POSTGRESQL_IVORY_URL',
                                      'resource' => {'name'  => 'loudly-yelling-1239',
                                                     'value' => 'postgres:///not-actually-ivory',
                                                     'type'  => 'heroku-postgresql:standard-0' }})
        example_attachments << additional_attachment
        stub_pg.schedule({ hour: '07', timezone: 'UTC',
                           schedule_name: 'HEROKU_POSTGRESQL_IVORY_URL' })
        stderr, stdout = execute("pg:backups schedule HEROKU_POSTGRESQL_IVORY_URL --at '07:00 UTC' --app example")
        expect(stderr).to be_empty
        expect(stdout).to match(/Scheduled automatic daily backups/)
      end

      context "demonstrating cultural imperialism" do
         {
          'PST' => 'America/Los_Angeles',
          'PDT' => 'America/Los_Angeles',
          'MST' => 'America/Boise',
          'MDT' => 'America/Boise',
          'CST' => 'America/Chicago',
          'CDT' => 'America/Chicago',
          'EST' => 'America/New_York',
          'EDT' => 'America/New_York',
          'Z'   => 'UTC',
          'GMT' => 'Europe/London',
          'BST' => 'Europe/London',
         }.each do |common_but_ambiguous_abbreviation, official_tz_db_name|
           it "translates #{common_but_ambiguous_abbreviation} to #{official_tz_db_name}" do
             stub_pg.schedule({ hour: '07', timezone: official_tz_db_name,
                                schedule_name: 'HEROKU_POSTGRESQL_RED_URL' })
             specified_time = "07:00 #{common_but_ambiguous_abbreviation}"
             stderr, stdout = execute("pg:backups schedule RED --at '#{specified_time}' --app example")
             expect(stderr).to be_empty
             expect(stdout).to match(/Scheduled automatic daily backups/)
           end
         end
      end
    end

    describe "heroku pg:backups unschedule" do
      let(:schedules) do
        [ { name: 'HEROKU_POSTGRESQL_GREEN_URL',
            uuid: 'ffffffff-ffff-ffff-ffff-ffffffffffff' },
          { name: 'DATABASE_URL',
            uuid: 'ffffffff-ffff-ffff-ffff-fffffffffffe' } ]
      end

      before do
        stub_pg.schedules.returns(schedules)
        allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver)
          .to receive(:app_attachments).and_return(example_attachments)
      end

      it "unschedules the specified backup" do
        stub_pg.unschedule
        stderr, stdout = execute("pg:backups unschedule green --confirm example")
        expect(stderr).to be_empty
        expect(stdout).to match(/Stopped automatic daily backups for/)
      end

      it "complains when called without an argument" do
        stderr, stdout = execute("pg:backups unschedule --confirm example")
        expect(stderr).to match(/Must specify schedule to cancel/)
        expect(stdout).to be_empty
      end

      it "indicates when no matching backup can be unscheduled" do
        stderr, stdout = execute("pg:backups unschedule red --confirm example")
        expect(stderr).to be_empty
        expect(stdout).to match(/No automatic daily backups for/)
      end
    end

    describe "heroku pg:backups" do
      let(:logged_at)  { Time.now }
      let(:started_at)  { Time.now }
      let(:finished_at) { Time.now }
      let(:from_name)   { 'RED' }
      let(:source_size) { 42 }
      let(:backup_size) { source_size / 2 }

      let(:logs) { [{ 'created_at' => logged_at, 'message' => "hello world" }] }
      let(:transfers) do
        [
         { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          :from_name => from_name, :to_name => 'BACKUP',
          :num => 1, :logs => logs,
          :from_type => 'pg_dump', :to_type => 'gof3r',
          :started_at => started_at, :finished_at => finished_at,
          :processed_bytes => backup_size, :source_bytes => source_size,
          :succeeded => true },
         { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          :from_name => from_name, :to_name => 'BACKUP',
          :num => 2, :logs => logs,
          :from_type => 'pg_dump', :to_type => 'gof3r',
          :started_at => started_at, :finished_at => finished_at,
          :processed_bytes => backup_size, :source_bytes => source_size,
          :succeeded => false },
        { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
         :from_type => 'gof3r', :to_type => 'pg_restore', num: 3,
         :started_at => Time.now, :finished_at => Time.now,
         :processed_bytes => 42, :succeeded => true },
        { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
         :from_type => 'gof3r', :to_type => 'pg_restore', num: 4,
         :started_at => Time.now, :finished_at => Time.now,
         :processed_bytes => 42, :succeeded => false },
        { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
         :from_type => 'pg_dump', :to_type => 'pg_restore', num: 5,
         :started_at => Time.now, :finished_at => Time.now,
         :from_name => "CRIMSON", :to_name => "CLOVER",
         :processed_bytes => 42, :succeeded => true },
        { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
         :from_type => 'pg_dump', :to_type => 'pg_restore', num: 6,
         :started_at => Time.now, :finished_at => Time.now,
         :from_name => "CRIMSON", :to_name => "CLOVER",
         :processed_bytes => 42, :succeeded => false },
        { :uuid => 'ffffffff-ffff-ffff-ffff-fffffffffffd',
          :from_name => from_name, :to_name => 'PGBACKUPS BACKUP',
          :num => 7, :logs => logs,
          :from_type => 'pg_dump', :to_type => 'gof3r',
          :started_at => started_at, :finished_at => finished_at,
          :processed_bytes => backup_size, :source_bytes => source_size,
          :options => { "pgbackups_name" => "b047" },
          :succeeded => true },
        { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          :from_type => 'gof3r', :to_type => 'pg_restore', num: 8,
          :started_at => Time.now, :finished_at => Time.now,
          :processed_bytes => 42, :succeeded => true, :warnings => 4},
        ]
      end

      before do
        (1..7).each do |n|
          stub_pgapp.transfers_get(n, true).
            returns(transfers.find { |xfer| xfer[:num] == n })
        end
        stub_pgapp.transfers.returns(transfers)
      end

      it "lists successful backups" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/b001\s*Completed/)
      end

      it "list failed backups" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/b002\s*Failed/)
      end

      it "lists old pgbackups" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/ob047\s*Completed/)
      end

      it "lists successful restores" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/r008\s*Finished with 4 warnings/)
      end

      it "lists completed restores with warnings" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/r004\s*Failed/)
      end


      it "lists failed restores" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/r004\s*Failed/)
      end

      it "lists successful copies" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/===\sCopies/)
        expect(stdout).to match(/c005\s*Completed/)
      end

      it "lists failed copies" do
        stderr, stdout = execute("pg:backups")
        expect(stdout).to match(/c006\s*Failed/)
      end

      describe "heroku pg:backups info" do
        it "displays info for the given backup" do
          stderr, stdout = execute("pg:backups info b001")
          expect(stderr).to be_empty
          expect(stdout).to eq <<-EOF
=== Backup info: b001
Database:    #{from_name}
Started:     #{started_at}
Finished:    #{finished_at}
Status:      Completed
Type:        Manual
Original DB Size: #{source_size}.0B
Backup Size:      #{backup_size}.0B (50% compression)
=== Backup Logs
#{logged_at}: hello world
          EOF
        end

        it "displays info for legacy PGBackups backups" do
          stderr, stdout = execute("pg:backups info ob047")
          expect(stderr).to be_empty
          expect(stdout).to eq <<-EOF
=== Backup info: ob047
Database:    #{from_name}
Started:     #{started_at}
Finished:    #{finished_at}
Status:      Completed
Type:        Manual
Original DB Size: #{source_size}.0B
Backup Size:      #{backup_size}.0B (50% compression)
=== Backup Logs
#{logged_at}: hello world
          EOF
        end

        it "defaults to the latest backup if none is specified" do
          stderr, stdout = execute("pg:backups info")
          expect(stderr).to be_empty
          expect(stdout).to eq <<-EOF
=== Backup info: ob047
Database:    #{from_name}
Started:     #{started_at}
Finished:    #{finished_at}
Status:      Completed
Type:        Manual
Original DB Size: #{source_size}.0B
Backup Size:      #{backup_size}.0B (50% compression)
=== Backup Logs
#{logged_at}: hello world
          EOF
        end

        it "does not display finished time or compression ratio if backup is not finished" do
          xfer = transfers.find { |xfer| xfer[:num] == 1 }
          xfer[:finished_at] = nil
          stderr, stdout = execute("pg:backups info b001")
          expect(stderr).to be_empty
          expect(stdout).to eq <<-EOF
=== Backup info: b001
Database:    #{from_name}
Started:     #{started_at}
Status:      Completed
Type:        Manual
Original DB Size: #{source_size}.0B
Backup Size:      #{backup_size}.0B
=== Backup Logs
#{logged_at}: hello world
          EOF
        end

        it "works when the progress is at 0 bytes" do
          xfer = transfers.find { |xfer| xfer[:num] == 1 }
          xfer[:processed_bytes] = 0
          stderr, stdout = execute("pg:backups info b001")
          expect(stderr).to be_empty
          expect(stdout).to eq <<-EOF
=== Backup info: b001
Database:    #{from_name}
Started:     #{started_at}
Finished:    #{finished_at}
Status:      Completed
Type:        Manual
Original DB Size: #{source_size}.0B
Backup Size:      0.00B (0% compression)
=== Backup Logs
#{logged_at}: hello world
          EOF
        end

        it "works when the source size is 0 bytes" do
          xfer = transfers.find { |xfer| xfer[:num] == 1 }
          xfer[:source_bytes] = 0
          stderr, stdout = execute("pg:backups info b001")
          expect(stderr).to be_empty
          expect(stdout).to eq <<-EOF
=== Backup info: b001
Database:    #{from_name}
Started:     #{started_at}
Finished:    #{finished_at}
Status:      Completed
Type:        Manual
Backup Size: #{backup_size}.0B
=== Backup Logs
#{logged_at}: hello world
          EOF
        end
      end
    end


    describe "heroku pg:backups restore" do
      let(:started_at)    { Time.parse('2001-01-01 00:00:00') }
      let(:finished_at_1) { Time.parse('2001-01-01 01:00:00') }
      let(:finished_at_2) { Time.parse('2001-01-01 02:00:00') }
      let(:finished_at_3) { Time.parse('2001-01-01 03:00:00') }

      let(:from_name)     { 'RED' }
      let(:to_url)        { 'https://example.com/my-backup' }

      let(:transfers) do
        [
         { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          :from_name => from_name, :to_name => 'BACKUP', :num => 1,
          :from_type => 'pg_dump', :to_type => 'gof3r', :to_url => to_url,
          :started_at => started_at, :finished_at => finished_at_2,
          :succeeded => true },
         { :uuid => 'ffffffff-ffff-ffff-ffff-fffffffffffd',
          :from_name => from_name, :to_name => 'PGBACKUPS BACKUP', :num => 2,
          :from_type => 'pg_dump', :to_type => 'gof3r', :to_url => to_url,
          :started_at => started_at, :finished_at => finished_at_1,
          :options => { "pgbackups_name" => "b047" },
          :succeeded => true },
         { :uuid => 'ffffffff-ffff-ffff-ffff-fffffffffffe',
          :from_name => from_name, :to_name => 'BACKUP', :num => 3,
          :from_type => 'pg_dump', :to_type => 'gof3r', :to_url => to_url,
          :started_at => started_at, :finished_at => finished_at_3,
          :succeeded => false }
        ]
      end

      let(:restore_info) do
        { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
         :from_type => 'gof3r', :to_type => 'pg_restore', num: 3,
         :started_at => Time.now, :finished_at => Time.now,
         :processed_bytes => 42, :succeeded => true }
      end

      before do
        allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver)
          .to receive(:app_attachments).and_return(example_attachments)
        stub_pgapp.transfers.returns(transfers)
      end

      it "triggers a restore of the given backup" do
        stub_pg.backups_restore(to_url).returns(restore_info)
        stub_pgapp.transfers_get.returns(restore_info)

        stderr, stdout = execute("pg:backups restore b001 red --confirm example")
        expect(stderr).to be_empty
        expect(stdout).to match(/Restore completed/)
      end

      it "defaults to the latest successful backup" do
        stub_pg.backups_restore(to_url).returns(restore_info)
        stub_pgapp.transfers_get.returns(restore_info)

        stderr, stdout = execute("pg:backups restore red --confirm example")
        expect(stderr).to be_empty
        expect(stdout).to match(/Restore completed/)
      end

      it "refuses to restore a backup that did not complete successfully" do
        stub_pg.backups_restore(to_url).returns(restore_info)
        stub_pgapp.transfers_get.returns(restore_info)

        stderr, stdout = execute("pg:backups restore b003 red --confirm example")
        expect(stderr).to match(/did not complete successfully/)
        expect(stdout).to be_empty
      end

      it "does not restore without confirmation" do
        stderr, stdout = execute("pg:backups restore b001 red")
        expect(stderr).to match(/Confirmation did not match example. Aborted./)
        expect(stdout).to match(/WARNING: Destructive Action/)
        expect(stdout).to match(/This command will affect the app: example/)
        expect(stdout).to match(/To proceed, type "example" or re-run this command with --confirm example/)
      end
    end

    describe "heroku pg:backups public-url" do
      let(:logged_at)   { Time.now }
      let(:started_at)  { Time.now }
      let(:finished_at) { Time.now }
      let(:from_name)   { 'RED' }
      let(:source_size) { 42 }
      let(:backup_size) { source_size / 2 }

      let(:logs) { [{ 'created_at' => logged_at, 'message' => "hello world" }] }
      let(:transfers) do
        [
         { :uuid => 'ffffffff-ffff-ffff-ffff-ffffffffffff',
          :from_name => from_name, :to_name => 'BACKUP',
          :num => 1, :logs => logs,
          :from_type => 'pg_dump', :to_type => 'gof3r',
          :started_at => started_at, :finished_at => finished_at,
          :processed_bytes => backup_size, :source_bytes => source_size,
          :succeeded => true },
         { :uuid => 'ffffffff-ffff-ffff-ffff-fffffffffffe',
          :from_name => from_name, :to_name => 'BACKUP',
          :num => 2, :logs => logs,
          :from_type => 'pg_dump', :to_type => 'gof3r',
          :started_at => started_at, :finished_at => finished_at,
          :processed_bytes => backup_size, :source_bytes => source_size,
          :succeeded => true }
        ]
      end
      let(:url1_info) do
        { :url => 'https://example.com/my-backup', :expires_at => Time.now }
      end
      let(:url2_info) do
        { :url => 'https://example.com/my-other-backup', :expires_at => Time.now }
      end

      before do
        stub_pgapp.transfers.returns(transfers)
        stub_pgapp.transfers_public_url(1).returns(url1_info)
        stub_pgapp.transfers_public_url(2).returns(url2_info)
      end

      it "gets a public url for the specified backup" do
        stderr, stdout = execute("pg:backups public-url b001")
        expect(stdout).to include url1_info[:url]
        expect(stdout).to match(/will expire at #{Regexp.quote(url1_info[:expires_at].to_s)}/)
      end

      it "only prints the url if stdout is not a tty" do
        fake_stdout = StringIO.new
        stderr, stdout = execute("pg:backups public-url b001", { :stdout => fake_stdout })
        expect(stdout.chomp).to eq url1_info[:url]
      end

      it "only prints the url if called with -q" do
        stderr, stdout = execute("pg:backups public-url b001 -q")
        expect(stdout.chomp).to eq url1_info[:url]
      end

      it "defaults to the latest backup if none is specified" do
        stderr, stdout = execute("pg:backups public-url")
        expect(stdout).to include url2_info[:url]
        expect(stdout).to match(/will expire at #{Regexp.quote(url2_info[:expires_at].to_s)}/)
      end
    end

  end
end
