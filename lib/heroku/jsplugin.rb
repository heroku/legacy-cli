class Heroku::JSPlugin
  include Heroku::Helpers

  def self.setup?
    File.exists? bin
  end

  def self.load!
    return unless setup?
    this = self
    commands.each do |plugin|
      klass = Class.new do
        def initialize(args, opts)
          @args = args
          @opts = opts
        end
      end
      klass.send(:define_method, :run) do
        ENV['HEROKU_APP'] = @opts[:app]
        exec this.bin, "#{plugin[:topic]}:#{plugin[:command]}", *@args
      end
      Heroku::Command.register_namespace(:name => plugin[:topic])
      Heroku::Command.register_command(
        :command   => "#{plugin[:topic]}:#{plugin[:command]}",
        :namespace => plugin[:topic],
        :klass     => klass,
        :method    => :run
      )
    end
  end

  def self.plugins
    return [] unless setup?
    @plugins ||= `#{bin} plugins`.lines.map do |line|
      name, version = line.split
      { :name => name, :version => version }
    end
  end

  def self.commands
    @commands ||= `#{bin} commands`.split.flat_map do |l|
      l.scan(/(\w+):(\w+)/).collect do |topic, command|
        { :topic => topic, :command => command }
      end
    end
  end

  def self.install(name)
    system "#{bin} plugins:install #{name}"
  end

  def self.version
    `#{bin} version`
  end

  def self.bin
    File.join(Heroku::Helpers.home_directory, ".heroku", "heroku-cli")
  end

  def self.setup
    return if File.exist? bin
    FileUtils.mkdir_p File.dirname(bin)
    resp = Excon.get(url, :middlewares => Excon.defaults[:middlewares] + [Excon::Middleware::Decompress])
    open(bin, "wb") do |file|
      file.write(resp.body)
    end
    File.chmod(0755, bin)
    if Digest::SHA1.file(bin).hexdigest != manifest['builds'][os][arch]['sha1']
      File.delete bin
      raise 'SHA mismatch for heroku-cli'
    end
  end

  def self.arch
    case RUBY_PLATFORM
    when /i386/
      "386"
    when /x64/
    else
      "amd64"
    end
  end

  def self.os
    case RUBY_PLATFORM
    when /darwin|mac os/
      "darwin"
    when /linux/
      "linux"
    when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
      "windows"
    else
      raise "unsupported on #{RUBY_PLATFORM}"
    end
  end

  def self.manifest
    @manifest ||= JSON.parse(Excon.get("https://d1gvo455cekpjp.cloudfront.net/heroku-cli/master/manifest.json").body)
  end

  def self.url
    manifest['builds'][os][arch]['url'] + ".gz"
  end
end
