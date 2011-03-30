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
  Gem::Specification.load("heroku.gemspec").dependencies.select do |dep|
    dep.type == :runtime
  end.map do |dep|
    %x{ bundle show #{dep.name} }
  end
end

def package_path(path, stream)
  Dir["#{path}/**/*.rb"].each do |file|
    relative = file.gsub(/^#{path}/, '')
    relative.gsub!(/^\//, '')
    stream.puts("__FILE__ #{relative}")
    stream.puts(File.read(file))
    stream.puts("__ENDFILE__")
  end
end

desc "Package as a single file"
task :package do
  out = File.open("pkg/heroku-#{Heroku::VERSION}.rb", "w")
  out.puts <<-PREAMBLE
    #!/usr/bin/env ruby

    EMBEDDED_FILES = DATA.read.split(/^__ENDFILE__/).inject({}) do |hash, file|
      lines = file.strip.split("\\n")
      next(hash) if lines.empty?
      name = lines.shift.split(" ").last
      hash.update(name => lines.join("\\n"))
    end

    module Kernel
      alias :original_require_before_packager :require
      private :original_require_before_packager

      @@already_required_by_packager = []

      def require(path)
        return if @@already_required_by_packager.include?(path)
        if data = EMBEDDED_FILES[\"\#{path}.rb\"]
          eval(data)
          @@already_required_by_packager << path
        else
          original_require_before_packager path
        end
      end
    end

    require "heroku"
    require "heroku/command"

    args = ARGV.dup
    ARGV.clear
    command = args.shift.strip rescue "help"
    Heroku::Command.run(command, args)

  PREAMBLE
  out.puts "__END__"
  package_path("lib", out)
  out.close
end

task :default => :spec
