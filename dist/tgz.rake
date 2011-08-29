file pkg("heroku-#{version}.tgz") => distribution_files do |t|
  tempdir do |dir|
    mkchdir("heroku-client") do
      assemble_distribution
      assemble_gems
      rm_rf "bin"
      assemble resource("tgz/heroku"), "heroku", 0755
    end

    sh "tar czvf #{t.name} heroku-client"
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
