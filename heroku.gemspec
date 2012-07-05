$:.unshift File.expand_path("../lib", __FILE__)
require "heroku/version"

Gem::Specification.new do |gem|
  gem.name    = "heroku"
  gem.version = Heroku::VERSION

  gem.author      = "Heroku"
  gem.email       = "support@heroku.com"
  gem.homepage    = "http://heroku.com/"
  gem.summary     = "Client library and CLI to deploy apps on Heroku."
  gem.description = "Client library and command-line tool to deploy and manage apps on Heroku."
  gem.executables = "heroku"
  gem.license     = "MIT"

  gem.files = %x{ git ls-files }.split("\n").select { |d| d =~ %r{^(License|README|bin/|data/|ext/|lib/|spec/|test/)} }

  gem.add_dependency "heroku-api",  "~> 0.2.7"
  gem.add_dependency "netrc",       "~> 0.7.5"
  gem.add_dependency "rest-client", "~> 1.6.1"
  gem.add_dependency "launchy",     ">= 0.3.2"
  gem.add_dependency "rubyzip"
end
