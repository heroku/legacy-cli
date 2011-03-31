$:.unshift File.expand_path("../lib", __FILE__)
require "heroku/version"

require 'rake'
require 'spec/rake/spectask'

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
  t.spec_opts = ['--colour --format progress --loadby mtime --reverse']
  t.spec_files = FileList['spec/**/*_spec.rb']
end

desc "Print specdocs"
Spec::Rake::SpecTask.new(:doc) do |t|
  t.spec_opts = ["--format", "specdoc", "--dry-run"]
  t.spec_files = FileList['spec/*_spec.rb']
end

desc "Generate RCov code coverage report"
Spec::Rake::SpecTask.new('rcov') do |t|
  t.spec_files = FileList['spec/*_spec.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', 'examples']
end

def gem_paths
  %x{ bundle show }.split("\n").map do |line|
    if line =~ /^  \* (.*?) \((.*?)\)/
      %x{ bundle show #{$1} }.strip
    end
  end.compact
end

GEM_BLACKLIST = %w( activesupport bundler heroku rack sequel sinatra sqlite3 sqlite3-ruby )

def copy_gems(package_gem_dir)
  lines = %x{ bundle show }.strip.split("\n")
  raise "error running bundler" unless $?.success?

  gemspec = Gem::Specification.load("heroku.gemspec")
  deps_by_name = gemspec.dependencies.inject({}) { |h,d| h.update(d.name => d) }

  %x{ bundle show }.split("\n").each do |line|
    if line =~ /^  \* (.*?) \((.*?)\)/
      next if GEM_BLACKLIST.include?($1)
      next if deps_by_name[$1] && deps_by_name[$1].type == :development
      puts "vendoring: #{$1}-#{$2}"
      gem_dir = %x{ bundle show #{$1} }.strip
      %x{ cp -R #{gem_dir} #{package_gem_dir}/ }
    end
  end.compact
end

def package_path(path, stream)
  puts "#{path}/**/*.rb"
  Dir["#{path}/**/*"].each do |file|
    next unless File.file?(file)
    puts "finding file: #{file}"
    relative = file.gsub(/^#{path}/, '')
    relative.gsub!(/^\//, '')
    stream.puts("__FILE__ #{relative}")
    stream.puts(File.read(file))
    stream.puts("__ENDFILE__")
  end
end

desc "Package as a single file"
task :package do
  base_dir = File.dirname(__FILE__)

  require "tmpdir"
  package_dir = "#{Dir.mktmpdir}/heroku-#{Heroku::VERSION}"
  package_gem_dir = "#{package_dir}/vendor/gems"

  puts "building in: #{package_dir}"
  %x{ mkdir -p #{package_gem_dir} }
  copy_gems package_gem_dir

  %x{ cp -R #{base_dir}/lib #{package_dir} }

  File.open("#{package_dir}/heroku", "w") do |file|
    file.puts <<-PREAMBLE
#!/usr/bin/env ruby

gem_dir = File.expand_path("../vendor/gems", __FILE__)
Dir["\#{gem_dir}/**/lib"].each do |libdir|
$:.unshift libdir
end

$:.unshift File.expand_path("../lib", __FILE__)

require 'heroku'
require 'heroku/command'

args = ARGV.dup
ARGV.clear
command = args.shift.strip rescue 'help'

Heroku::Command.run(command, args)
    PREAMBLE
  end

  %x{ chmod +x #{package_dir}/heroku }

  if plugins = (ENV["PLUGINS"] || "").split(" ")
    plugins.each do |plugin|
      puts "plugin: #{plugin}"
      %x{ mkdir -p #{package_dir}/plugins }
      %x{ cd #{package_dir}/plugins && git clone #{plugin} 2>&1 }
      %x{ rm -rf $(find #{package_dir}/plugins -name .git) }
    end
  end

  %x{ cd #{package_dir}/.. && tar czvpf #{base_dir}/pkg/heroku-#{Heroku::VERSION}.tgz * 2>&1 }

  puts "package: pkg/heroku-#{Heroku::VERSION}.tgz"
end

task :default => :spec
