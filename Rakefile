require 'rake'
require 'spec/rake/spectask'

desc "Run all specs"
Spec::Rake::SpecTask.new('spec') do |t|
	t.spec_files = FileList['spec/*_spec.rb']
end

desc "Print specdocs"
Spec::Rake::SpecTask.new(:doc) do |t|
	t.spec_opts = ["--format", "specdoc", "--dry-run"]
	t.spec_files = FileList['spec/*_spec.rb']
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

version = "0.1"
name = "heroku"

spec = Gem::Specification.new do |s|
	s.name = name
	s.version = version
	s.summary = "Client library and CLI to the Heroku deployment platform."
	s.description = "Client library and command-line tool to create, destroy, clone, and otherwise manage apps built on the Heroku platform.  Wraps the Heroku REST API."
	s.author = "Adam Wiggins"
	s.email = "feedback@heroku.com"
	s.homepage = "http://heroku.com/"
	s.executables = [ "heroku" ]
	s.default_executable = "heroku"

	s.platform = Gem::Platform::RUBY
	s.has_rdoc = false
	
	s.files = %w(Rakefile) +
		Dir.glob("{bin,lib,spec}/**/*")
	
	s.require_path = "lib"
	s.bindir = "bin"
end

Rake::GemPackageTask.new(spec) do |p|
	p.need_tar = true if RUBY_PLATFORM !~ /mswin/
end

task :install => [ :test, :package ] do
	sh %{sudo gem install pkg/#{name}-#{version}.gem}
end

task :uninstall => [ :clean ] do
	sh %{sudo gem uninstall #{name}}
end

Rake::TestTask.new do |t|
	t.libs << "spec"
	t.test_files = FileList['spec/*_spec.rb']
	t.verbose = true
end

Rake::RDocTask.new do |rdoc|
	rdoc.rdoc_dir = 'doc/rdoc'
	rdoc.options << '--line-numbers'
	rdoc.rdoc_files.add ['lib/**/*.rb', 'doc/**/*.rdoc']
end

CLEAN.include [ 'build/*', '**/*.o', '**/*.so', '**/*.a', 'lib/*-*', '**/*.log', 'pkg', 'lib/*.bundle', '*.gem', '.config' ]

