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

file pkg("heroku-#{version}.zip.sha256") => pkg("heroku-#{version}.zip") do |t|
  File.open(t.name, "w") do |file|
    file.puts Digest::SHA256.file(t.prerequisites.first).hexdigest
  end
end

task "zip:build" => pkg("heroku-#{version}.zip")
task "zip:sign"  => pkg("heroku-#{version}.zip.sha256")

def zip_signature
  File.read(pkg("heroku-#{version}.zip.sha256")).chomp
end

task "zip:clean" do
  clean pkg("heroku-#{version}.zip")
end

task "zip:release" => %w( zip:build zip:sign ) do |t|
  store pkg("heroku-#{version}.zip"), "heroku-client/heroku-client-#{version}.zip"
  store pkg("heroku-#{version}.zip"), "heroku-client/heroku-client-beta.zip" if beta?
  store pkg("heroku-#{version}.zip"), "heroku-client/heroku-client.zip" unless beta?

  sh "heroku config:add UPDATE_HASH=#{zip_signature} -a toolbelt" unless beta?
end
