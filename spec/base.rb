require 'rubygems'

require 'spec'
require 'fileutils'
require 'tmpdir'
require 'webmock/rspec'

require 'heroku/command'
require 'heroku/commands/base'
Dir["#{File.dirname(__FILE__)}/../lib/heroku/commands/*"].each { |c| require c }

include WebMock

def stub_api_request(method, path)
  stub_request(method, "https://api.heroku.com#{path}")
end

def prepare_command(klass)
  command = klass.new(['--app', 'myapp'])
  command.stub!(:args).and_return([])
  command.stub!(:display)
  command.stub!(:heroku).and_return(mock('heroku client', :host => 'heroku.com'))
  command.stub!(:extract_app).and_return('myapp')
  command
end

def with_blank_git_repository(&block)
  sandbox = File.join(Dir.tmpdir, "heroku", Process.pid.to_s)
  FileUtils.mkdir_p(sandbox)

  Dir.chdir(sandbox) do
    bash "git init"
    block.call
  end

  FileUtils.rm_rf(sandbox)
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