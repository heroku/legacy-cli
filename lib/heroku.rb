require "heroku/client"
require "heroku/updater"
require "heroku/version"

module Heroku

  USER_AGENT = 'legacy' # left for backwards compatibility with old toolbelt bin files

  def self.user_agent
    @@user_agent ||= "heroku-gem/#{Heroku::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"
  end

  def self.user_agent=(agent)
    @@user_agent = agent
  end

end
