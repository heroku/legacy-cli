require "bundler/setup"

PROJECT_ROOT = File.expand_path("..", __FILE__)
$:.unshift "#{PROJECT_ROOT}/lib"
require "heroku"

def version
  Heroku::VERSION
end

Dir.glob('tasks/helpers/*.rb').each { |r| import r }
Dir.glob('tasks/*.rake').each { |r| import r }

desc "clean"
task :clean do
  rm_r "dist"
  mkdir "dist"
end

desc "release v#{version}"
task "release" => ["can_release", "clean", "build", "tgz:release", "zip:release", "manifest:update", "deb:release", "gem:release", "git:tag"] do
  puts("released v#{version}")
end

desc "build v#{version}"
task "build" => ["tgz:build", "zip:build", "deb:build", "gem:build"] do
  puts("built v#{version}")
end

desc "check to see if v#{version} is releaseable"
task :can_release do
  if ENV['HEROKU_RELEASE_ACCESS'].nil? || ENV['HEROKU_RELEASE_SECRET'].nil?
    $stderr.puts "cannot release, #{version}, HEROKU_RELEASE_ACCESS and HEROKU_RELEASE_SECRET must be set"
    exit(1)
  end
  system './bin/heroku auth:whoami' or exit 1
  if `gem list ^heroku$ --remote` == "heroku (#{version})\n"
    $stderr.puts "cannot release #{version}, v#{version} is already released"
    exit(1)
  end
end

task :default => :spec
