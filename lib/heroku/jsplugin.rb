require 'rbconfig'
require 'heroku/helpers/env'

class Heroku::JSPlugin
  extend Heroku::Helpers

  def self.try_takeover(command, args)
    run('dashboard', nil, []) if ARGV.length == 0
    if command == 'help' && args.length > 0
      return
    elsif args.include?('--help') || args.include?('-h')
      return
    end
    command = find_command(command)
    return if !command || command[:hidden]
    run(ARGV[0], nil, ARGV[1..-1])
  end

  def self.load!
    topics.each do |topic|
      Heroku::Command.register_namespace(
        :name => topic['name'],
        :description => " #{topic['description']}"
      ) unless topic['hidden'] || Heroku::Command.namespaces.include?(topic['name'])
    end
    commands.each do |command|
      Heroku::Command.register_command(command)
      if command[:default]
        Heroku::Command.register_command(
          :command   => command[:namespace],
          :namespace => command[:namespace],
          :klass     => command[:klass],
          :method    => :run,
          :banner    => command[:banner],
          :summary   => command[:summary],
          :help      => command[:help],
          :hidden    => command[:hidden],
        )
      end
    end
  end

  def self.plugins
    @plugins ||= `"#{bin}" plugins`.lines.map do |line|
      name, version, extra = line.split
      { :name => name, :version => version, :extra => extra }
    end
  end

  def self.is_plugin_installed?(name)
    plugins.any? { |p| p[:name] == name }
  end

  def self.topics
    commands_info['topics']
  end

  def self.commands
    @commands ||= begin
                    this = self
                    commands_info['commands'].map do |command|
                      help = "\n\n#{command['fullHelp']}"
                      klass = Class.new do
                        def initialize(args, opts)
                          @args = args
                          @opts = opts
                        end
                      end
                      klass.send(:define_method, :run) do
                        this.run(command['topic'], command['command'], ARGV[1..-1])
                      end
                      {
                        :command   => command['command'] ? "#{command['topic']}:#{command['command']}" : command['topic'],
                        :namespace => command['topic'],
                        :klass     => klass,
                        :method    => :run,
                        :banner    => command['usage'],
                        :summary   => " #{command['description']}",
                        :help      => help,
                        :hidden    => command['hidden'],
                        :default   => command['default'],
                        :js        => true,
                      }
                    end
                  end
  end

  def self.commands_info
    @commands_info ||= begin
                         info = json_decode(`"#{bin}" commands --json`)
                         error "error getting commands #{$?}" if $? != 0
                         info
                       end
  end

  def self.install(name, opts={})
    system "\"#{bin}\" plugins:install #{name}" if opts[:force] || !self.is_plugin_installed?(name)
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

    if windows? && [bin, cmd, *args].any? {|arg| ! arg.ascii_only?}
      system bin, cmd, *args
      exit $?.exitstatus
    else
      exec bin, cmd, *args
    end
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

  def self.find_command(s)
    commands.find { |c| c[:command] == s }
  end

  # check if release is one that isn't updateable
  def self.check_if_old
    File.delete(bin) if windows? && setup? && version.start_with?("heroku-cli/4.24")
    File.delete(bin) if setup? && version.start_with?("heroku-cli/4.27.5-")
  rescue => e
    Rollbar.error(e)
  rescue
  end

  def self.windows?
    os == 'windows'
  end
end
