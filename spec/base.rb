require 'rubygems'

gem 'rake'
gem 'rspec',       '~> 1.2.0'
gem 'taps',        '~> 0.3.0'
gem 'webmock'
gem 'rest-client', '~> 1.4.0'
gem 'launchy',     '~> 0.3.2'
gem 'json_pure',   '>= 1.2.0', '< 1.5.0'

require 'spec'
require 'fileutils'
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

module SandboxHelper
  def bash(cmd)
    FileUtils.cd(@sandbox) { |d| return `#{cmd}` }
  end
end

module Heroku::Helpers
  def display(msg, newline=true)
  end
end