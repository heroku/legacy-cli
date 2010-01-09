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

task :default => :spec

######################################################

require 'rake'
require 'rake/testtask'
require 'rake/clean'
require 'rake/gempackagetask'
require 'rake/rdoctask'
require 'fileutils'
include FileUtils

begin
	require 'lib/heroku'
	version = Heroku::Client.version
rescue LoadError
	version = ""

  puts "ERROR: Missing one or more dependencies. Make sure jeweler is installed and run: rake check_dependencies"
	puts
end

name = "heroku"

spec = Gem::Specification.new do |s|
	s.name = name
	s.version = version
	s.summary = "Client library and CLI to deploy Rails apps on Heroku."
	s.description = "Client library and command-line tool to manage and deploy Rails apps on Heroku."
	s.author = "Heroku"
	s.email = "support@heroku.com"
	s.homepage = "http://heroku.com/"
	s.executables = [ "heroku" ]
	s.default_executable = "heroku"
	s.rubyforge_project = "heroku"

	s.platform = Gem::Platform::RUBY
	s.has_rdoc = false
	
	s.files = %w(Rakefile) +
		Dir.glob("{bin,lib,spec}/**/*")
	
	s.require_path = "lib"
	s.bindir = "bin"

	s.add_development_dependency 'rake'
	s.add_development_dependency 'rspec', '~> 1.2.0'
	s.add_development_dependency 'taps',  '~> 0.2.23'

	s.add_dependency 'rest-client', '~> 1.2'
	s.add_dependency 'launchy',     '~> 0.3.2'
	s.add_dependency 'json',        '~> 1.2.0'
end

Rake::GemPackageTask.new(spec) do |p|
	p.need_tar = true if RUBY_PLATFORM !~ /mswin/
end

desc "Install #{name} gem (#{version})"
task :install => [ :test, :package ] do
	sh %{sudo gem install pkg/#{name}-#{version}.gem}
end

desc "Uninstall #{name} gem"
task :uninstall => [ :clean ] do
	sh %{sudo gem uninstall #{name}}
end

Rake::TestTask.new do |t|
	t.libs << "spec"
	t.test_files = FileList['spec/*_spec.rb']
	t.verbose = true
end

CLEAN.include [ 'build/*', '**/*.o', '**/*.so', '**/*.a', 'lib/*-*', '**/*.log', 'pkg', 'lib/*.bundle', '*.gem', '.config' ]

begin
  require 'jeweler'
  Jeweler::Tasks.new(spec) do |s|
    s.version = version
  end
  Jeweler::RubyforgeTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: sudo gem install jeweler"
end
