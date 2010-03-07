gem 'rest-client', '~> 1.3.0'
gem 'launchy',     '~> 0.3.2'
gem 'json_pure',   '~> 1.2.0'

module Heroku; end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/heroku')

require 'client'
