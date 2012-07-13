require "heroku/client"
require "heroku/version"

module Heroku

  USER_AGENT = "heroku-gem/#{Heroku::VERSION} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"

end
