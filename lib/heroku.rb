module Heroku; end

gem 'rest-client', '= 1.0.3'
gem 'launchy',     '= 0.3.2'
gem 'json',        '= 1.1.0'

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/heroku')

require 'client'
