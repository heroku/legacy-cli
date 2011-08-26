module Heroku; end

require "heroku/updater"
Heroku::Updater.inject_libpath

require "heroku/client"
