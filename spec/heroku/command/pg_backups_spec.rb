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
  end
end
