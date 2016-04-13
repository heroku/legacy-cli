namespace :deb do
  desc "build deb"
  task :build => dist("heroku-toolbelt-#{version}.apt")

  desc "release deb"
  task :release => :build do |t|
    s3_store_dir dist("heroku-toolbelt-#{version}.apt"), "apt", "heroku-toolbelt"
  end

  file dist("heroku-toolbelt-#{version}.apt") => [ dist("heroku-toolbelt-#{version}.apt/heroku-#{version}.deb"), dist("heroku-toolbelt-#{version}.apt/heroku-toolbelt-#{version}.deb") ] do |t|
    abort "Don't publish .debs of pre-releases!" if version =~ /[a-zA-Z]$/

    cd t.name do |dir|
      touch "Sources"

      sh "apt-ftparchive packages . > Packages"
      sh "gzip -c Packages > Packages.gz"
      sh "apt-ftparchive -c #{resource("deb/heroku-toolbelt/apt-ftparchive.conf")} release . > Release"
      sh "gpg --digest-algo SHA512 -abs -u 0F1B0520 -o Release.gpg Release"
    end
  end


  file dist("heroku-toolbelt-#{version}.apt/heroku-#{version}.deb") => distribution_files("deb") do |t|
    mkdir_p File.dirname(t.name)
    tempdir do
      mkdir_p "usr/local/heroku"
      cd "usr/local/heroku" do
        assemble_distribution
        assemble_gems
        assemble resource("deb/heroku/heroku"), "bin/heroku", 0755
      end

      assemble resource("deb/heroku/control"), "control"
      assemble resource("deb/heroku/postinst"), "postinst"

      sh "tar czf data.tar.gz usr/local/heroku --owner=root --group=root"
      sh "tar czf control.tar.gz control postinst"

      File.open("debian-binary", "w") do |f|
        f.puts "2.0"
      end

      sh "ar -r #{t.name} debian-binary control.tar.gz data.tar.gz"
    end
  end

  file dist("heroku-toolbelt-#{version}.apt/heroku-toolbelt-#{version}.deb") do |t|
    tempdir do |dir|
      assemble resource("deb/heroku-toolbelt/control"), "DEBIAN/control"
      sh "dpkg-deb --build . #{t.name}"
    end
  end
end
