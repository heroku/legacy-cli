require "bundler/setup"

PROJECT_ROOT = File.expand_path("..", __FILE__)
$:.unshift "#{PROJECT_ROOT}/lib"
require "heroku"

def version
  Heroku::VERSION
end

Dir.glob('tasks/helpers/*.rb').each { |r| import r }
Dir.glob('tasks/*.rake').each { |r| import r }

desc "release v#{version}"
task "release" => ["can_release", "build", "tgz:release", "zip:release", "manifest:update", "deb:release", "gem:release", "git:tag"] do
  puts("released v#{version}")
end

desc "build v#{version}"
task "build" => ["tgz:build", "zip:build", "deb:build", "gem:build"] do
  puts("built v#{version}")
end

desc "check to see if v#{version} is not already released"
task :can_release do
  if `gem list ^heroku$ --remote` == "heroku (#{version})\n"
    $stderr.puts "cannot release v#{version}"
    exit(1)
  end
end

task :default => :spec
