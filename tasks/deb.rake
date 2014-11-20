FOREMAN_VERSION = "0.75.0"

namespace :deb do
  desc "build deb"
  task :build => dist("heroku-toolbelt-#{version}.apt")

  desc "release deb"
  task :release => :build do |t|
    s3_store_dir dist("heroku-toolbelt-#{version}.apt"), "apt", "heroku-toolbelt"
  end

  file dist("heroku-toolbelt-#{version}.apt") => [ dist("heroku-toolbelt-#{version}.apt/foreman-#{FOREMAN_VERSION}.deb"), dist("heroku-toolbelt-#{version}.apt/heroku-#{version}.deb"), dist("heroku-toolbelt-#{version}.apt/heroku-toolbelt-#{version}.deb") ] do |t|
    abort "Don't publish .debs of pre-releases!" if version =~ /[a-zA-Z]$/

    cd t.name do |dir|
      touch "Sources"

      sh "apt-ftparchive packages . > Packages"
      sh "gzip -c Packages > Packages.gz"
      sh "apt-ftparchive -c #{resource("deb/heroku-toolbelt/apt-ftparchive.conf")} release . > Release"
      sh "gpg -abs -u 0F1B0520 -o Release.gpg Release"
    end
  end


  file dist("heroku-toolbelt-#{version}.apt/foreman-#{FOREMAN_VERSION}.deb") do |t|
    mkdir_p File.dirname(t.name)
    unless File.exist? "dist/foreman"
      sh "git clone https://github.com/ddollar/foreman.git dist/foreman"
    end
    cd "dist/foreman" do
      sh "git checkout v#{FOREMAN_VERSION}"
      rm_rf ".bundle"
      rm_rf "apt-#{FOREMAN_VERSION}"
      Bundler.with_clean_env do
        sh "unset GEM_HOME RUBYOPT; bundle install --path vendor/bundle" or abort
        sh "unset GEM_HOME RUBYOPT; bundle exec rake deb:build" or abort
      end
      mv "pkg/apt-#{FOREMAN_VERSION}/foreman-#{FOREMAN_VERSION}.deb", t.name
    end
  end

  file dist("heroku-toolbelt-#{version}.apt/heroku-#{version}.deb") => distribution_files("deb") do |t|
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
