file pkg("heroku-#{version}.gem") => distribution_files do |t|
  sh "gem build heroku.gemspec"
  sh "mv heroku-#{version}.gem #{t.name}"
end

task "gem:build" => pkg("heroku-#{version}.gem")

task "gem:clean" do
  clean pkg("heroku-#{version}.gem")
end

task "gem:release" => "gem:build" do |t|
  sh "parka push -f #{pkg("heroku-#{version}.gem")}"
end
