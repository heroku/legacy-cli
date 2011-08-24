module Heroku

  def self.distribution_files
    Dir[File.expand_path("../../{bin,data,lib}/**/*", __FILE__)]
  end
end


require "heroku/updater"
Heroku::Updater.inject_libpath

require 'heroku/client'
