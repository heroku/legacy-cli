require 'rubygems'

# ruby 1.9.2 drops . from the load path
$:.unshift File.expand_path("../..", __FILE__)

require 'spec'
require 'fileutils'
require 'tmpdir'
require 'webmock/rspec'
require 'fakefs/safe'

require 'salesforce/command'
require 'salesforce/commands/base'
Dir["#{File.dirname(__FILE__)}/../lib/salesforce/commands/*"].each { |c| require c }

include WebMock::API

def stub_api_request(method, path)
  stub_request(method, "https://api.heroku.com#{path}")
end

def prepare_command(klass)
  command = klass.new(['--app', 'myapp'])
  command.stub!(:args).and_return([])
  command.stub!(:display)
  command.stub!(:salesforce).and_return(mock('salesforce client', :host => 'heroku.com'))
  command.stub!(:extract_app).and_return('myapp')
  command
end

def with_blank_git_repository(&block)
  sandbox = File.join(Dir.tmpdir, "salesforce", Process.pid.to_s)
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

module Salesforce::Helpers
  def display(msg, newline=true)
  end
end

require 'spec/support/display_message_matcher'
Spec::Runner.configure do |config|
  config.include(DisplayMessageMatcher)
end
