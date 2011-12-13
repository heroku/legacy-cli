require "rubygems"
require "bundler/setup"

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

task :local_build => ['gem:build', 'pkg:build', 'tgz:build', 'zip:build'] do
  puts 'Built [gem, pkg, tgz, zip]'
end

task :release => ['deb:release', 'exe:release', 'gem:release', 'pkg:release', 'tgz:release', 'zip:release'] do
  puts 'Released [deb, exe, gem, pkg, tgz, zip]'
end

task :changelog do
  timestamp = Time.now.utc.strftime('%m/%d/%Y')
  sha = `git log | head -1`.split(' ').last
  changelog = ["#{version} #{timestamp} #{sha}"]
  changelog << ('=' * changelog[0].length)
  changelog << ''

  last_sha = `cat changelog.txt | head -1`.split(' ').last
  shortlog = `git shortlog #{last_sha}..HEAD`
  for line in shortlog.split("\n")
    case line
    when /^\S/, /^\s*$/ # committer, blank
      next
    else
      changelog << line.lstrip!
    end
  end
  changelog.concat ['', '', '']

  old_changelog = File.read('changelog.txt')
  File.open('changelog.txt', 'w') do |file|
    file.write(changelog.join("\n"))
    file.write(old_changelog)
  end
end
