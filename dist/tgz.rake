file pkg("heroku-#{version}.tgz") => distribution_files("tgz") do |t|
  tempdir do |dir|
    mkchdir("heroku-client") do
      assemble_distribution
      assemble_gems
      assemble resource("tgz/heroku"), "bin/heroku", 0755
    end

    sh "chmod -R go+r heroku-client"
    sh "sudo chown -R 0:0 heroku-client"
    sh "tar czf #{t.name} heroku-client"
    sh "sudo chown -R $(whoami) heroku-client"
  end
end

task "tgz:build" => pkg("heroku-#{version}.tgz")

task "tgz:clean" do
  clean pkg("heroku-#{version}.tgz")
end

task "tgz:release" => "tgz:build" do |t|
  store pkg("heroku-#{version}.tgz"), "heroku-client/heroku-client-#{version}.tgz"
  store pkg("heroku-#{version}.tgz"), "heroku-client/heroku-client-beta.tgz" if beta?
  store pkg("heroku-#{version}.tgz"), "heroku-client/heroku-client.tgz" unless beta?
end
