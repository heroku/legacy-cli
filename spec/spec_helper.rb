require "rubygems"
require "bundler/setup"

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
end

require "rspec"
require "rr"
require "fakefs/safe"
require "webmock/rspec"

include WebMock::API

def stub_api_request(method, path)
  stub_request(method, "https://api.heroku.com#{path}")
end

def prepare_command(klass)
  command = klass.new
  command.stub!(:app).and_return("myapp")
  command.stub!(:ask).and_return("")
  command.stub!(:display)
  command.stub!(:heroku).and_return(mock('heroku client', :host => 'heroku.com'))
  command
end

def execute(command_line)
  extend RR::Adapters::RRMethods

  args = command_line.split(" ")
  command = args.shift

  Heroku::Command.load
  object, method = Heroku::Command.prepare_run(command, args)

  $command_output = []

  def object.print(line=nil)
    last_line = $command_output.pop || ""
    last_line.concat(line)
    $command_output.push last_line
  end

  def object.puts(line=nil)
    $command_output << line
  end

  def object.error(line=nil)
    $command_output << line
  end

  any_instance_of(Heroku::Command::Base) do |base|
    stub(base).extract_app.returns("myapp")
  end

  object.send(method)
end

def output
  ($command_output || []).join("\n")
end

def any_instance_of(klass, &block)
  extend RR::Adapters::RRMethods
  any_instance_of(klass, &block)
end

def fail_command(message)
  raise_error(Heroku::Command::CommandFailed, message)
end

def stub_core
  stubbed_core = nil
  any_instance_of(Heroku::Client) do |core|
    stubbed_core = stub(core)
  end
  stubbed_core
end

def stub_rendezvous
  stubbed_rendezvous = nil
  any_instance_of(Heroku::Client::Rendezvous) do |rendezvous|
    stubbed_rendezvous = stub(rendezvous)
  end
  stubbed_rendezvous
end

def with_blank_git_repository(&block)
  sandbox = File.join(Dir.tmpdir, "heroku", Process.pid.to_s)
  FileUtils.mkdir_p(sandbox)

  old_dir = Dir.pwd
  Dir.chdir(sandbox)

  bash "git init"
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

module Heroku::Helpers
  def display(msg, newline=true)
  end
end

require "support/display_message_matcher"

Rspec.configure do |config|
  config.color_enabled = true
  config.include DisplayMessageMatcher
end

