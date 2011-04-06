require 'rubygems'

# ruby 1.9.2 drops . from the load path
$:.unshift File.expand_path("../..", __FILE__)

require 'spec'
require 'fileutils'
require 'tmpdir'
require 'webmock/rspec'
require 'fakefs/safe'

require 'heroku/command'
require 'heroku/command/base'
Dir["#{File.dirname(__FILE__)}/../lib/heroku/command/*"].each { |c| require c }

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

require 'spec/support/display_message_matcher'
Spec::Runner.configure do |config|
  config.include(DisplayMessageMatcher)
end
