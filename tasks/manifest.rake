namespace :manifest do
  desc "puts VERSION file into s3"
  task :update do
    if beta?
      $stderr.puts "skipping manifest:update since this is a beta release"
      next
    end

    tempdir do |dir|
      File.open("VERSION", "w") do |file|
        file.puts version
      end
      puts "Current version: #{version}"
      s3_store "#{dir}/VERSION", "heroku-client/VERSION"
    end
  end
end
