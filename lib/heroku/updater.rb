require 'heroku/helpers'

module Heroku
  module Updater

    def self.installed_client_path
      File.expand_path("../../..", __FILE__)
    end

    def self.updated_client_path
      File.join(Heroku::Helpers.home_directory, ".heroku", "client")
    end

    def self.latest_local_version
      installed_version = client_version_from_path(installed_client_path)
      updated_version = client_version_from_path(updated_client_path)
      if compare_versions(updated_version, installed_version) > 0
        updated_version
      else
        installed_version
      end
    end

    def self.client_version_from_path(path)
      version_file = File.join(path, "lib/heroku/version.rb")
      if File.exists?(version_file)
        File.read(version_file).match(/VERSION = "([^"]+)"/)[1]
      else
        '0.0.0'
      end
    end

    def self.disable(message=nil)
      @disable = message if message
      @disable
    end

    def self.check_disabled!
      if disable
        Heroku::Helpers.error(disable)
      end
    end

    def self.update(url, autoupdate=false)
      require "excon"
      require "fileutils"
      require "tmpdir"
      require "zip/zip"

      user_agent = "heroku-toolbelt/#{latest_local_version} (#{RUBY_PLATFORM}) ruby/#{RUBY_VERSION}"
      if autoupdate
        user_agent += ' autoupdate'
      end

      Dir.mktmpdir do |download_dir|

        # follow redirect, if one exists
        headers = Excon.head(
          url,
          :headers => {
            'User-Agent' => user_agent
          }
        ).headers
        if headers['Location']
          url = headers['Location']
        end

        File.open("#{download_dir}/heroku.zip", "wb") do |file|
          file.print Excon.get(url).body
        end

        Zip::ZipFile.open("#{download_dir}/heroku.zip") do |zip|
          zip.each do |entry|
            target = File.join(download_dir, entry.to_s)
            FileUtils.mkdir_p File.dirname(target)
            zip.extract(entry, target) { true }
          end
        end

        FileUtils.rm "#{download_dir}/heroku.zip"

        old_version = latest_local_version
        new_version = client_version_from_path(download_dir)

        if compare_versions(new_version, old_version) < 0 && !autoupdate
          Heroku::Helpers.error("Installed version (#{old_version}) is newer than the latest available update (#{new_version})")
        end

        FileUtils.rm_rf updated_client_path
        FileUtils.mkdir_p File.dirname(updated_client_path)
        FileUtils.cp_r  download_dir, updated_client_path

        new_version
      end
    end

    def self.compare_versions(first_version, second_version)
      first_version.split('.').map {|part| Integer(part) rescue part} <=> second_version.split('.').map {|part| Integer(part) rescue part}
    end

    def self.inject_libpath
      background_update!

      old_version = client_version_from_path(installed_client_path)
      new_version = client_version_from_path(updated_client_path)

      if compare_versions(new_version, old_version) > 0
        $:.unshift File.join(updated_client_path, "lib")
        vendored_gems = Dir[File.join(updated_client_path, "vendor", "gems", "*")]
        vendored_gems.each do |vendored_gem|
          $:.unshift File.join(vendored_gem, "lib")
        end
        load('heroku/updater.rb') # reload updated updater
      end
    end

    def self.background_update!
      if File.exists?(File.join(Heroku::Helpers.home_directory, ".heroku", "autoupdate"))
        pid = fork do
          begin
            require "excon"
            latest_version = Heroku::Helpers.json_decode(Excon.get('http://rubygems.org/api/v1/gems/heroku.json').body)['version']

            if compare_versions(latest_version, latest_local_version) > 0
              update("https://toolbelt.herokuapp.com/download/zip", true)
            end
          rescue Exception => ex
            # trap all errors
          ensure
            @background_updating = false
          end
        end
        Process.detach pid
      end
    end
  end
end
