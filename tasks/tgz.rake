namespace :tgz do
  desc "build tgz"
  task :build => dist("heroku-#{version}.tgz")

  desc "release tgz"
  task :release => :build do |t|
    s3_store dist("heroku-#{version}.tgz"), "heroku-client/heroku-client-#{version}.tgz"
    s3_store dist("heroku-#{version}.tgz"), "heroku-client/heroku-client-beta.tgz" if beta?
    s3_store dist("heroku-#{version}.tgz"), "heroku-client/heroku-client.tgz" unless beta?
  end

  file dist("heroku-#{version}.tgz") => distribution_files("tgz") do |t|
    tempdir do |dir|
      mkdir "heroku-client"
      cd "heroku-client" do
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
end
