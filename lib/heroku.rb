gem 'rest-client', '~> 1.2.0'

module Heroku; end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/heroku')

require 'client'
