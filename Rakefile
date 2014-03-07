require "rubygems"

PROJECT_ROOT = File.expand_path("..", __FILE__)
$:.unshift "#{PROJECT_ROOT}/lib"

require "heroku/version"
require "rspec/core/rake_task"

desc "Run all specs"
RSpec::Core::RakeTask.new(:spec) do |t|
  t.verbose = true
end

task :default => :spec

## dist

require "erb"
require "fileutils"
require "tmpdir"

def assemble(source, target, perms=0644)
  FileUtils.mkdir_p(File.dirname(target))
  File.open(target, "w") do |f|
    f.puts ERB.new(File.read(source)).result(binding)
  end
  File.chmod(perms, target)
end

def assemble_distribution(target_dir=Dir.pwd)
  distribution_files.each do |source|
    target = source.gsub(/^#{project_root}/, target_dir)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
  end
end

GEM_BLACKLIST = %w( bundler heroku )

def assemble_gems(target_dir=Dir.pwd)
  lines = %x{ bundle show }.strip.split("\n")
  raise "error running bundler" unless $?.success?

  %x{ env BUNDLE_WITHOUT="development:test" bundle show }.split("\n").each do |line|
    if line =~ /^  \* (.*?) \((.*?)\)/
      next if GEM_BLACKLIST.include?($1)
      puts "vendoring: #{$1}-#{$2}"
      gem_dir = %x{ bundle show #{$1} }.strip
      FileUtils.mkdir_p "#{target_dir}/vendor/gems"
      %x{ cp -R "#{gem_dir}" "#{target_dir}/vendor/gems" }
    end
  end.compact
end

def beta?
  Heroku::VERSION.to_s =~ /pre/
end

def clean(file)
  rm file if File.exists?(file)
end

def distribution_files(type=nil)
  require "heroku/distribution"
  base_files = Heroku::Distribution.files
  type_files = type ?
    Dir[File.expand_path("../dist/resources/#{type}/**/*", __FILE__)] :
    []
  #base_files.concat(type_files)
  base_files
end

def mkchdir(dir)
  FileUtils.mkdir_p(dir)
  Dir.chdir(dir) do |dir|
    yield(File.expand_path(dir))
  end
end

def pkg(filename)
  FileUtils.mkdir_p("pkg")
  File.expand_path("../pkg/#{filename}", __FILE__)
end

def project_root
  File.dirname(__FILE__)
end

def resource(name)
  File.expand_path("../dist/resources/#{name}", __FILE__)
end

def s3_connect
  return if @s3_connected

  require "aws/s3"

  unless ENV["HEROKU_RELEASE_ACCESS"] && ENV["HEROKU_RELEASE_SECRET"]
    puts "please set HEROKU_RELEASE_ACCESS and HEROKU_RELEASE_SECRET in your environment"
    exit 1
  end

  AWS::S3::Base.establish_connection!(
    :access_key_id => ENV["HEROKU_RELEASE_ACCESS"],
    :secret_access_key => ENV["HEROKU_RELEASE_SECRET"]
  )

  @s3_connected = true
end

def store(package_file, filename, bucket="assets.heroku.com")
  s3_connect
  puts "storing: #{filename}"
  AWS::S3::S3Object.store(filename, File.open(package_file), bucket, :access => :public_read)
end

def tempdir
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      yield(dir)
    end
  end
end

def version
  require "heroku/version"
  Heroku::VERSION
end

Dir[File.expand_path("../dist/**/*.rake", __FILE__)].each do |rake|
  import rake
end

def poll_ci
  require("multi_json")
  require("net/http")
  data = MultiJson.parse(Net::HTTP.get("travis-ci.org", "/heroku/heroku.json"))
  case data["last_build_status"]
  when nil
    print(".")
    sleep(1)
    poll_ci
  when 0
    puts("SUCCESS")
  when 1
    puts("FAILURE")
  end
end

desc("Check current ci status and/or wait for build to finish.")
task "ci" do
  poll_ci
end

desc("open jenkins")
task "jenkins" do
  `open http://dx-jenkins.herokai.com`
end

desc("Create a new changelog article")
task "changelog" do
  changelog = <<-CHANGELOG
Heroku CLI v#{version} released with 

A new version of the Heroku CLI is available with 

See the [CLI changelog](https://github.com/heroku/heroku/blob/master/CHANGELOG) for details and update by using \\`heroku update\\`.
CHANGELOG

  `echo "#{changelog}" | pbcopy`

  `open http://devcenter.heroku.com/admin/changelog_items/new`
end

desc("Release the latest version")
task "release" => ["gem:release", "jenkins", "tgz:release", "zip:release", "manifest:update"] do
  puts("Released v#{version}")
end

desc("Display statistics")
task "stats" do
  require "heroku/command"
  Dir[File.join(File.dirname(__FILE__), 'lib', 'heroku', 'command', '*.rb')].each do |file|
    require(file)
  end
  commands, namespaces = Hash.new {|hash, key| hash[key] = 0}, []
  Heroku::Command.commands.keys.each do |key|
    data = key.split(':')
    unless data.first == data.last
      commands[data.last] += 1
    end
    namespaces |= [data.first]
  end
  puts "#{namespaces.length} Namespaces:"
  puts "#{namespaces.join(', ')}"
  puts
  puts "#{commands.keys.length} Commands:"
  max = commands.values.max
  max.downto(0).each do |count|
    keys = commands.keys.select {|key| commands[key] == count}
    unless keys.empty?
      puts("#{count}x #{keys.join(', ')}")
    end
  end
end
