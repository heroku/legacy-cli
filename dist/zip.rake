require "zip/zip"

file pkg("heroku-#{version}.zip") => distribution_files("zip") do |t|
  tempdir do |dir|
    mkchdir("heroku-client") do
      assemble_distribution
      assemble_gems
      Zip::ZipFile.open(t.name, Zip::ZipFile::CREATE) do |zip|
        Dir["**/*"].each do |file|
          zip.add(file, file) { true }
        end
      end
    end
  end
end

task "zip:build" => pkg("heroku-#{version}.zip")

task "zip:clean" do
  clean pkg("heroku-#{version}.zip")
end

task "zip:release" => "zip:build" do |t|
  store pkg("heroku-#{version}.zip"), "heroku-client/heroku-client-#{version}.zip"
  store pkg("heroku-#{version}.zip"), "heroku-client/heroku-client-beta.zip" if beta?
  store pkg("heroku-#{version}.zip"), "heroku-client/heroku-client.zip" unless beta?
end
