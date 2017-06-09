namespace :deb do
  desc "build deb"
  task :build => dist("heroku-toolbelt-#{version}.apt")

  desc "release deb"
  task :release => :build do |t|
    s3_store_dir dist("heroku-toolbelt-#{version}.apt"), "apt", "heroku-toolbelt"
  end

  file dist("heroku-toolbelt-#{version}.apt") => [ dist("heroku-toolbelt-#{version}.apt/heroku-#{version}.deb")] do |t|
    mkdir_p t.name
  end


  file dist("heroku-toolbelt-#{version}.apt/heroku-#{version}.deb") => distribution_files("deb") do |t|
    mkdir_p File.dirname(t.name)
    tempdir do
      mkdir_p "usr/local/heroku"
      assemble resource("deb/heroku/control"), "control"
      assemble resource("deb/heroku/postinst"), "postinst"

      sh "tar czf data.tar.gz usr/local/heroku --owner=root --group=root"
      sh "tar czf control.tar.gz control postinst"

      File.open("debian-binary", "w") do |f|
        f.puts "2.0"
      end

      sh "ar -r #{t.name} debian-binary control.tar.gz data.tar.gz"
    end

    tempdir do |dir|
      assemble resource("deb/heroku-toolbelt/control"), "DEBIAN/control"
      sh "dpkg-deb --build . #{File.dirname(t.name)}/heroku-toolbelt-#{version}.deb"
    end

    cd File.dirname(t.name) do |dir|
      touch "Sources"

      sh "apt-ftparchive packages . > Packages"
      sh "gzip -c Packages > Packages.gz"
      sh "apt-ftparchive -c #{resource("deb/heroku-toolbelt/apt-ftparchive.conf")} release . > Release"
      sh "gpg --digest-algo SHA512 -abs -u 0F1B0520 -o Release.gpg Release"
    end
  end
end
