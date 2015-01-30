require "digest"
require "fileutils"
require "heroku/helpers"

module Heroku
  module Updater
    extend Heroku::Helpers

    def self.error(message)
      raise Heroku::Command::CommandFailed.new(message)
    end

    def self.updating_lock_path
      File.join(Heroku::Helpers.home_directory, ".heroku", "updating")
    end

    def self.installed_client_path
      File.expand_path("../../..", __FILE__)
    end

    def self.updated_client_path
      File.join(Heroku::Helpers.home_directory, ".heroku", "client")
    end

    def self.latest_version
      http_get('http://assets.heroku.com/heroku-client/VERSION').chomp
    end

    def self.official_zip_hash
      http_get('https://toolbelt.heroku.com/update/hash').chomp
    end

    def self.http_get(url)
      require 'excon'
      require 'heroku/excon'
      Excon.get_with_redirect(url, :nonblock => false).body
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

    def self.needs_update?
      compare_versions(latest_version, latest_local_version) > 0
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

    def self.wait_for_lock(wait_for=5, check_every=0.5)
      path = updating_lock_path
      start = Time.now.to_i
      while File.exists?(path)
        sleep check_every
        if (Time.now.to_i - start) > wait_for
          Heroku::Helpers.error "Unable to acquire update lock"
        end
      end
      FileUtils.mkdir_p File.dirname(path)
      FileUtils.touch path
      yield
    ensure
      FileUtils.rm_f path
    end

    def self.autoupdate
      return warn_if_out_of_date if disable
      # if we've updated in the last hour, don't try again
      if File.exists?(last_autoupdate_path)
        return if (Time.now.to_i - File.mtime(last_autoupdate_path).to_i) < 60*60
      end
      FileUtils.mkdir_p File.dirname(last_autoupdate_path)
      FileUtils.touch last_autoupdate_path
      update
    end

    def self.warn_if_out_of_date
      $stderr.puts "WARNING: Toolbelt v#{latest_version} update available." if needs_update?
    end

    def self.update(prerelease=false)
      return unless prerelease || needs_update?

      stderr_print 'updating...'
      wait_for_lock do
        require "tmpdir"
        require "zip/zip"

        Dir.mktmpdir do |download_dir|
          zip_filename = "#{download_dir}/heroku.zip"
          if prerelease
            url = "https://toolbelt.heroku.com/download/beta-zip"
          else
            url = "https://toolbelt.heroku.com/download/zip"
          end

          download_file(url, zip_filename)
          unless prerelease
            hash = Digest::SHA256.file(zip_filename).hexdigest
            error "Update hash signature mismatch" unless hash == official_zip_hash
          end

          extract_zip(zip_filename, download_dir)
          FileUtils.rm_f zip_filename

          version = client_version_from_path(download_dir)

          # do not replace beta version if it is old
          return if version < latest_local_version

          FileUtils.rm_rf updated_client_path
          FileUtils.mkdir_p File.dirname(updated_client_path)
          FileUtils.cp_r  download_dir, updated_client_path

          stderr_puts "done. Updated to #{version}"
          version
        end
      end
    end

    def self.download_file(from_url, to_filename)
      File.open(to_filename, "wb") do |file|
        file.print http_get(from_url)
      end
    end

    def self.extract_zip(filename, dir)
      Zip::ZipFile.open(filename) do |zip|
        zip.each do |entry|
          target = File.join(dir, entry.to_s)
          FileUtils.mkdir_p File.dirname(target)
          zip.extract(entry, target) { true }
        end
      end
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
    end

    def self.last_autoupdate_path
      File.join(Heroku::Helpers.home_directory, ".heroku", "autoupdate.last")
    end
  end
end
