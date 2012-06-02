require 'heroku/helpers'

module Heroku
  module Updater

    DEFAULT_UPDATE_URL = "http://assets.heroku.com/heroku-client/heroku-client.zip"

    extend Heroku::Helpers

    def self.updated_client_path
      File.join(home_directory, ".heroku", "client")
    end

    def self.installed_client_path
      puts [:z, $0]
    end

    def self.client_version_from_path(path)
      version_file = File.join(path, "lib/heroku/version.rb")
      return Gem::Version.new("0.0") unless File.exists?(version_file)
      Gem::Version.new(File.read(version_file).match(/VERSION = "([^"]+)"/)[1])
    end

    def self.disable(message=nil)
      @disable = message if message
      @disable
    end

    def self.check_disabled!
      error disable if disable
    end

    def self.update(url=DEFAULT_UPDATE_URL)
      require "fileutils"
      require "tmpdir"
      require "zip/zip"

      Dir.mktmpdir do |download_dir|
        File.open("#{download_dir}/heroku.zip", "wb") do |file|
          file.print RestClient.get(url).body
        end

        Zip::ZipFile.open("#{download_dir}/heroku.zip") do |zip|
          zip.each do |entry|
            target = File.join(download_dir, entry.to_s)
            FileUtils.mkdir_p File.dirname(target)
            zip.extract(entry, target) { true }
          end
        end

        FileUtils.rm "#{download_dir}/heroku.zip"

        old_version = Gem::Version.new(Heroku::VERSION)
        new_version = client_version_from_path(download_dir)

        if old_version > new_version
          error "Installed version (#{old_version}) is newer than the latest available update (#{new_version})"
        end

        FileUtils.rm_rf updated_client_path
        FileUtils.cp_r  download_dir, updated_client_path

        new_version
      end
    end

    def self.inject_libpath
      old_version = Gem::Version.new(Heroku::VERSION)
      new_version = client_version_from_path(updated_client_path)
      return unless new_version > old_version

      $:.unshift File.join(updated_client_path, "lib")
      vendored_gems = Dir[File.join(updated_client_path, "vendor", "gems", "*")]
      vendored_gems.each do |vendored_gem|
        $:.unshift File.join(vendored_gem, "lib")
      end
    end
  end
end
