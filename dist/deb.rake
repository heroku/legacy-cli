file pkg("heroku-toolbelt-#{version}.deb") => distribution_files("deb") do |t|
  tempdir do |dir|
    mkchdir("usr/local/heroku") do
      assemble_distribution
      assemble_gems
      assemble resource("deb/heroku"), "bin/heroku", 0755
    end

    assemble resource("deb/control"), "control"
    assemble resource("deb/postinst"), "postinst"

    sh "tar czvf data.tar.gz usr/local/heroku --owner=root --group=root"
    sh "tar czvf control.tar.gz control postinst"

    File.open("debian-binary", "w") do |f|
      f.puts "2.0"
    end

    deb = File.basename(t.name)

    sh "ar -r #{t.name} debian-binary control.tar.gz data.tar.gz"
  end
end

task "deb:build" => pkg("heroku-toolbelt-#{version}.deb")

task "deb:clean" do
  clean pkg("heroku-toolbelt-#{version}.deb")
end

task "deb:release" => "deb:build" do |t|
  tempdir do |dir|
    cp pkg("heroku-toolbelt-#{version}.deb"), "#{dir}/heroku-toolbelt-#{version}.deb"
    touch "Sources"
    sh "apt-ftparchive packages . > Packages"
    sh "gzip -c Packages > Packages.gz"
    sh "apt-ftparchive release . > Release"
    sh "gpg -abs -u 0F1B0520 -o Release.gpg Release"

    Dir["*"].each do |file|
      store file, "apt/#{File.basename(file)}", "heroku-toolbelt"
    end
  end
end
