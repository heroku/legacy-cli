module Heroku

  def self.distribution_files
    Dir[File.expand_path("../../{bin,data,lib}/**/*", __FILE__)]
  end

  module Updater
    def self.home_directory
      running_on_windows? ? ENV['USERPROFILE'] : ENV['HOME']
    end

    def self.running_on_windows?
      RUBY_PLATFORM =~ /mswin32|mingw32/
    end

    def self.updated_client_path
      File.join(home_directory, ".heroku", "client")
    end

    def self.update
      require "fileutils"
      require "tmpdir"
      require "zip/zip"

      FileUtils.mkdir_p updated_client_path

      client_path = nil

      Dir.mktmpdir do |dir|
        File.open("heroku.zip", "wb") do |file|
          file.print RestClient.get "http://assets.heroku.com/heroku-client/heroku-client.zip"
        end

        #system %{ mv heroku.zip /tmp }

        Zip::ZipFile.open("heroku.zip") do |zip|
          zip.each do |entry|
            target = File.join(updated_client_path, entry.to_s)
            FileUtils.mkdir_p File.dirname(target)
            zip.extract(entry, target) { true }
          end
        end
      end
    end

    def self.inject_libpath
      $:.unshift updated_client_path
    end
  end

end


Heroku::Updater.inject_libpath

require 'heroku/client'
