$stdin = File.new("/dev/null")

require "rubygems"

require "coveralls"
Coveralls.wear!

require "excon"

require "heroku/cli"
require "heroku/client"
require "rspec"
require "rr"
require "fakefs/safe"
require 'tmpdir'
require "webmock/rspec"
require "shellwords"

include WebMock::API

WebMock::HttpLibAdapters::ExconAdapter.disable!
Excon.defaults[:mock] = true

def api
  Heroku::API.new(:api_key => "pass", :mock => true)
end

def org_api
  Heroku::Client::Organizations.api(:mock => true)
end

def stub_api_request(method, path)
  stub_request(method, "https://api.heroku.com#{path}")
end

def prepare_command(klass)
  command = klass.new
  allow(command).to receive(:app).and_return("example")
  allow(command).to receive(:ask).and_return("")
  allow(command).to receive(:display)
  allow(command).to receive(:hputs)
  allow(command).to receive(:hprint)
  allow(command).to receive(:heroku).and_return(double('heroku client', :host => 'heroku.com'))
  command
end

def execute(command_line, opts={})
  extend RR::Adapters::RRMethods

  args = command_line.shellsplit
  command = args.shift

  Heroku::Command.load
  object, method = Heroku::Command.prepare_run(command, args)

  any_instance_of(Heroku::Command::Base) do |base|
    stub(base).app.returns("example")
  end

  stub(Heroku::Auth).get_credentials.returns(['email@example.com', 'apikey01'])
  stub(Heroku::Auth).api_key.returns('apikey01')

  original_stdin, original_stderr, original_stdout = $stdin, $stderr, $stdout

  fake_tty_stdout = StringIO.new
  class << fake_tty_stdout
    def tty?
      true
    end
  end

  $stdin  = captured_stdin  = opts.fetch(:stdin, StringIO.new)
  $stderr = captured_stderr = opts.fetch(:stderr, StringIO.new)
  $stdout = captured_stdout = opts.fetch(:stdout, fake_tty_stdout)

  begin
    object.send(method)
  rescue SystemExit
  ensure
    $stdin, $stderr, $stdout = original_stdin, original_stderr, original_stdout
    Heroku::Command.current_command = nil
  end

  [captured_stderr.string, captured_stdout.string]
end

def any_instance_of(klass, &block)
  extend RR::Adapters::RRMethods
  any_instance_of(klass, &block)
end

def run(command_line)
  capture_stdout do
    begin
      Heroku::CLI.start(*command_line.split(" "))
    rescue SystemExit
    end
  end
end

alias heroku run

def capture_stderr(&block)
  original_stderr = $stderr
  $stderr = captured_stderr = StringIO.new
  begin
    yield
  ensure
    $stderr = original_stderr
  end
  captured_stderr.string
end

def capture_stdout(&block)
  original_stdout = $stdout
  $stdout = captured_stdout = StringIO.new
  begin
    yield
  ensure
    $stdout = original_stdout
  end
  captured_stdout.string
end

def fail_command(message)
  raise_error(Heroku::Command::CommandFailed, message)
end

def stub_core
  @stubbed_core ||= begin
    stubbed_core = nil
    any_instance_of(Heroku::Client) do |core|
      stubbed_core = stub(core)
    end
    stub(Heroku::Auth).user.returns("email@example.com")
    stub(Heroku::Auth).password.returns("pass")
    stub(Heroku::Client).auth.returns("apikey01")
    stub(Heroku::Updater).autoupdate
    stubbed_core
  end
end

def stub_pg
  @stubbed_pg ||= begin
    stubbed_pg = nil
    any_instance_of(Heroku::Client::HerokuPostgresql) do |pg|
      stubbed_pg = stub(pg)
    end
    stubbed_pg
  end
end

def stub_pgapp
  @stubbed_pgapp ||= begin
    stubbed_pgapp = nil
    any_instance_of(Heroku::Client::HerokuPostgresqlApp) do |pg|
      stubbed_pgapp = stub(pg)
    end
    stubbed_pgapp
  end
end

def stub_pgbackups
  @stubbed_pgbackups ||= begin
    stubbed_pgbackups = nil
    any_instance_of(Heroku::Client::Pgbackups) do |pgbackups|
      stubbed_pgbackups = stub(pgbackups)
    end
    stubbed_pgbackups
  end
end

def stub_rendezvous
  @stubbed_rendezvous ||= begin
    stubbed_rendezvous = nil
    any_instance_of(Heroku::Client::Rendezvous) do |rendezvous|
      stubbed_rendezvous = stub(rendezvous)
    end
    stubbed_rendezvous
  end
end

def stub_organizations
  @stub_organizations ||= begin
    stub_organizations = nil
    any_instance_of(Heroku::Client::Organizations) do |organizations|
      stub_organizations = stub(organizations)
    end
    stub_organizations
  end
end

def with_blank_git_repository(&block)
  sandbox = File.join(Dir.tmpdir, "heroku", Process.pid.to_s)
  FileUtils.mkdir_p(sandbox)

  old_dir = Dir.pwd
  Dir.chdir(sandbox)

  `git init`
  block.call

  FileUtils.rm_rf(sandbox)
ensure
  Dir.chdir(old_dir)
end

module SandboxHelper
  def bash(cmd)
    `#{cmd}`
  end
end

require "heroku/helpers"
module Heroku::Helpers
  @home_directory = Dir.mktmpdir
  undef_method :home_directory
  def home_directory
    @home_directory
  end
  undef_method :has_http_git_entry_in_netrc
  def has_http_git_entry_in_netrc
    true
  end
  undef_method :error_log
  def error_log(*obj); end
  undef_method :error_log_path
  def error_log_path
    'error_log_path'
  end
end

require "heroku/git"
module Heroku::Git
  def self.check_git_version; end
end

require "heroku/rollbar"
module Heroku::Rollbar
  def self.error(e); end
end

require "support/display_message_matcher"
require "support/organizations_mock_helper"
require "support/addons_helper"

RSpec.configure do |config|
  config.include DisplayMessageMatcher
  config.order = 'rand'
  config.before { Heroku::Helpers.error_with_failure = false }
  config.after { RR.reset }
end

