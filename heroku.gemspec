require "rubygems"
require "parka/specification"

Parka::Specification.new do |gem|
  gem.name    = "heroku"
  gem.version = Heroku::Client.version

  gem.author   = "Heroku"
  gem.email    = "support@heroku.com"
  gem.homepage = "http://heroku.com/"

  gem.summary     = "Client library and CLI to deploy Rails apps on Heroku."
  gem.description = "lient library and command-line tool to manage and deploy Rails apps on Heroku."
  gem.homepage    = "http://github.com/ddollar/foreman"
  gem.executables = "heroku"
end
