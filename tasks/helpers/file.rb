require "erb"
require "fileutils"
require "tmpdir"

GEM_BLACKLIST = %w( bundler heroku )

def assemble(source, target, perms=0644)
  FileUtils.mkdir_p(File.dirname(target))
  File.open(target, "w") do |f|
    f.puts ERB.new(File.read(source)).result(binding)
  end
  File.chmod(perms, target)
end

def assemble_distribution(target_dir=Dir.pwd)
  distribution_files.each do |source|
    target = source.gsub(/^#{PROJECT_ROOT}/, target_dir)
    FileUtils.mkdir_p(File.dirname(target))
    FileUtils.cp(source, target)
  end
end

def assemble_gems(target_dir=Dir.pwd)
  %x{ env BUNDLE_WITHOUT="development:test" bundle show }.split("\n").each do |line|
    if line =~ /^  \* (.*?) \((.*?)\)/
      next if GEM_BLACKLIST.include?($1)
      gem_dir = %x{ bundle show #{$1} }.strip
      FileUtils.mkdir_p "#{target_dir}/vendor/gems"
      %x{ cp -R "#{gem_dir}" "#{target_dir}/vendor/gems" }
    end
  end.compact
end

def beta?
  Heroku::VERSION.to_s =~ /pre/
end

def distribution_files(type=nil)
  Dir[File.expand_path("{bin,data,lib}/**/*", PROJECT_ROOT)].select do |file|
    File.file?(file)
  end
end

def dist(filename)
  FileUtils.mkdir_p("dist")
  File.expand_path("dist/#{filename}", PROJECT_ROOT)
end

def resource(name)
  File.expand_path("resources/#{name}", PROJECT_ROOT)
end

def tempdir
  Dir.mktmpdir do |dir|
    Dir.chdir(dir) do
      yield(dir)
    end
  end
end
