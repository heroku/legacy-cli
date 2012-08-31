require "fileutils"

require 'heroku/helpers'

module Heroku
  module Updater

    def self.autoupdating_path
      File.join(Heroku::Helpers.home_directory, ".heroku", "autoupdating")
    end

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
      if ENV['HEROKU_AUTOUPDATE'] = 'true'
        if File.exists?(autoupdating_path)
          Heroku::Helpers.error('autoupdate in progress')
        end
      end

      require "excon"
      require "heroku"
      require "tmpdir"
      require "zip/zip"

      latest_version = Heroku::Helpers.json_decode(Excon.get('http://rubygems.org/api/v1/gems/heroku.json').body)['version']

      if compare_versions(latest_version, latest_local_version) > 0
        Dir.mktmpdir do |download_dir|

          # follow redirect, if one exists
          headers = Excon.head(
            url,
            :headers => {
              'User-Agent' => Heroku.user_agent
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
      else
        false # already up to date
      end
    ensure
      FileUtils.rm_f(autoupdating_path)
    end

    def self.compare_versions(first_version, second_version)
      first_version.split('.').map {|part| Integer(part) rescue part} <=> second_version.split('.').map {|part| Integer(part) rescue part}
    end

    def self.inject_libpath
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

      background_update!
    end

    def self.autoupdate?
      !@disable && File.exists?(File.join(Heroku::Helpers.home_directory, ".heroku", "autoupdate"))
    end

    def self.background_update!
      # default autoupdate for users with no plugins who haven't updated before
      unless File.exists?(File.join(Heroku::Helpers.home_directory, '.heroku'))
        FileUtils.mkdir_p(File.join(Heroku::Helpers.home_directory, '.heroku'))
        FileUtils.touch(File.join(Heroku::Helpers.home_directory, '.heroku', 'autoupdate'))
      end
      if autoupdate? && !File.exists?(autoupdating_path)
        FileUtils.touch(autoupdating_path)
        log_path = File.join(Heroku::Helpers.home_directory, '.heroku', 'autoupdate.log')
        pid = if defined?(RUBY_VERSION) and RUBY_VERSION =~ /^1\.8\.\d+/
          fork do
            ENV['HEROKU_AUTOUPDATE'] = 'true'
            exec("heroku update &> #{log_path}")
          end
        else
          spawn(ENV.to_hash.merge({'HEROKU_AUTOUPDATE' => 'true'}), "heroku update", {:err => :out, :out => log_path})
        end
        Process.detach(pid)
      end
    end
  end
end
