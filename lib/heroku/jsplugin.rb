require 'rbconfig'
require 'heroku/helpers/env'

ALWAYS_RUBY_COMMANDS = [
  'plugins',
  'plugins:install',
  'plugins:uninstall',
  'version',
  'update',
]

class Heroku::JSPlugin
  extend Heroku::Helpers

  def self.list
    system "\"#{bin}\" plugins"
  end

  def self.try_takeover(command)
    return if ALWAYS_RUBY_COMMANDS.include?(command)
    run((ARGV[0] || "help"), nil, ARGV[1..-1])
  end

  def self.install(name, opts={})
    system "\"#{bin}\" plugins:install #{name}"
    error "error installing plugin #{name}" if $? != 0
  end

  def self.uninstall(name)
    system "\"#{bin}\" plugins:uninstall #{name}"
  end

  def self.update(channel='')
    system "\"#{bin}\" update #{channel}"
  end

  def self.version
    `"#{bin}" version`
  end

  def self.app_dir
    localappdata = Heroku::Helpers::Env['LOCALAPPDATA']
    xdg_data_home = Heroku::Helpers::Env['XDG_DATA_HOME'] || File.join(Heroku::Helpers.home_directory, '.local', 'share')

    if windows? && localappdata
      File.join(localappdata, 'heroku')
    else
      File.join(xdg_data_home, 'heroku')
    end
  end

  def self.bin
    File.join(app_dir, 'cli', 'bin', windows? ? 'heroku.exe' : 'heroku')
  end

  def self.setup
    check_if_old
    return if setup?
    require 'excon'
    require 'rubygems/package'
    $stderr.print "heroku-cli: Installing CLI..."

    Dir.mktmpdir do |tmp|
      archive = File.join(tmp, "heroku.tar.gz")
      open(archive, "wb") do |file|
        streamer = lambda do |chunk, remaining_bytes, total_bytes|
          file.write(chunk)
          $stderr.print "\rheroku-cli: Installing CLI... #{((total_bytes-remaining_bytes)/1000.0/1000).round(2)}MB/#{(total_bytes/1000.0/1000).round(2)}MB"
        end
        opts = excon_opts.merge(
          :chunk_size => 324000,
          :read_timeout => 300,
          :response_block => streamer
        )
        retries = 5
        begin
          Excon.get(url, opts)
        rescue => e
          if retries > 0
            $stderr.puts "\nError: #{e}\n#{e.backtrace.join("\n")}\n\nretrying...\n"
            retries = retries - 1
            retry
          else
            raise e
          end
        end
      end

      if Digest::SHA256.file(archive).hexdigest != manifest['builds']["#{os}-#{arch}"]['sha256']
        raise 'SHA mismatch for heroku.tar.gz'
      end

      FileUtils.mkdir_p(app_dir)
      FileUtils.rm_rf(File.join(app_dir, 'cli'))
      Zlib::GzipReader.open(archive) do |gz|
        Gem::Package::TarReader.new(gz) do |tar|
          dest = nil
          tar.each do |entry|
            if entry.full_name == '././@LongLink'
              dest = File.join(app_dir, entry.read.strip.gsub(/^heroku/, 'cli'))
              next
            end
            dest ||= File.join(app_dir, entry.full_name.gsub(/^heroku/, 'cli'))
            if entry.directory?
              FileUtils.mkdir_p(dest, mode: entry.header.mode)
            elsif entry.file?
              File.open(dest, 'wb') do |f|
                f.print entry.read
              end
              FileUtils.chmod(entry.header.mode, dest)
            elsif entry.header.typeflag == '2' && !windows?
              File.symlink entry.header.linkname, dest
            end
            dest = nil
          end
        end
      end
    end
    $stderr.puts
    version
  end

  def self.setup?
    File.exist? bin
  end

  def self.run(topic, command, args)
    cmd = command ? "#{topic}:#{command}" : topic
    bin = self.bin

    system bin, cmd, *args
    status = $?.exitstatus
    exit status if status != 127
  end

  def self.spawn(topic, command, args)
    cmd = command ? "#{topic}:#{command}" : topic
    system self.bin, cmd, *args
  end

  def self.arch
    case RbConfig::CONFIG['host_cpu']
    when /x86_64/
      "amd64"
    when /arm/
      "arm"
    else
      "386"
    end
  end

  def self.os
    case RbConfig::CONFIG['host_os']
    when /darwin|mac os/
      raise "#{arch} is not supported" unless arch == "amd64"
      "darwin"
    when /linux/
      "linux"
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      "windows"
    when /openbsd/
      "openbsd"
    when /freebsd/
      "freebsd"
    else
      raise "unsupported on #{RbConfig::CONFIG['host_os']}"
    end
  end

  def self.manifest
    @manifest ||= JSON.parse(Excon.get("https://cli-assets.heroku.com/branches/stable/gz/manifest.json", excon_opts).body)
  end

  def self.excon_opts
    if windows? || ENV['HEROKU_SSL_VERIFY'] == 'disable'
      # S3 SSL downloads do not work from ruby in Windows
      {:ssl_verify_peer => false}
    else
      {}
    end
  end

  def self.url
    manifest['builds']["#{os}-#{arch}"]['url']
  end

  # check if release is one that isn't updateable
  def self.check_if_old
    return unless setup?
    v = version.gsub(/heroku-cli\/([.\d]+)-.+/, '\1').chomp.split('.').map(&:to_i)
    File.delete(bin) if windows? && v[0] < 5 # delete older than 5.x
    File.delete(bin) if windows? && v[0] == 5 && v[1] < 5 # delete older than 5.5.x
    File.delete(bin) if v == [4, 27, 5]
  rescue => e
    Rollbar.error(e)
  rescue
  end

  def self.windows?
    os == 'windows'
  end
end
