require "heroku/client"
require "heroku/updater"
require "heroku/version"

module Heroku

  USER_AGENT = 'legacy' # left for backwards compatibility with old toolbelt bin files

  def self.user_agent
    type = if ENV['GEM_HOME'] && __FILE__.include?(ENV['GEM_HOME'])
      'gem'
    else
      'toolbelt'
    end
    user_agent = "heroku-#{type}/#{Heroku::Updater.latest_local_version} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"
    if Heroku::Updater.autoupdate?
      user_agent << ' autoupdate'
    end
    user_agent
  end

end
