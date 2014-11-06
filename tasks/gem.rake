namespace :gem do
  desc "build gem"
  task :build do
    sh "gem build heroku.gemspec"
    mv "heroku-#{version}.gem", dist("heroku-#{version}.gem")
  end

  desc "release gem"
  task :release => :build do
    sh "gem push #{dist("heroku-#{version}.gem")}"
  end
end
