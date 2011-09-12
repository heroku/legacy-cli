require "erb"

file pkg("heroku-#{version}.pkg") => distribution_files("pkg") do |t|
  tempdir do |dir|
    mkchdir("heroku-toolbelt") do
      assemble_distribution
      assemble_gems
      assemble resource("pkg/heroku"), "bin/heroku", 0755
    end

    kbytes = %x{ du -ks heroku-toolbelt | cut -f 1 }
    num_files = %x{ find heroku-toolbelt | wc -l }

    mkdir_p "pkg"
    mkdir_p "pkg/Resources"
    mkdir_p "pkg/heroku-#{version}.pkg"

    dist = File.read(resource("pkg/Distribution.erb"))
    dist = ERB.new(dist).result(binding)
    File.open("pkg/Distribution", "w") { |f| f.puts dist }

    dist = File.read(resource("pkg/PackageInfo.erb"))
    dist = ERB.new(dist).result(binding)
    File.open("pkg/heroku-#{version}.pkg/PackageInfo", "w") { |f| f.puts dist }

    mkdir_p "pkg/heroku-#{version}.pkg/Scripts"
    cp resource("pkg/postinstall"), "pkg/heroku-#{version}.pkg/Scripts/postinstall"
    chmod 0755, "pkg/heroku-#{version}.pkg/Scripts/postinstall"

    sh %{ mkbom -s heroku-toolbelt pkg/heroku-#{version}.pkg/Bom }

    Dir.chdir("heroku-toolbelt") do
      sh %{ pax -wz -x cpio . > ../pkg/heroku-#{version}.pkg/Payload }
    end

    sh %{ curl http://assets.foreman.io.s3.amazonaws.com/foreman/foreman.pkg -o foreman-full.pkg }
    sh %{ pkgutil --expand foreman-full.pkg foreman-full }
    sh %{ mv foreman-full/foreman-*.pkg pkg/foreman.pkg }

    sh %{ pkgutil --flatten pkg heroku-#{version}.pkg }

    cp_r "heroku-#{version}.pkg", t.name
  end
end

task "pkg:build" => pkg("heroku-#{version}.pkg")

task "pkg:clean" do
  clean pkg("heroku-#{version}.pkg")
end

task "pkg:release" => "pkg:build" do |t|
  store pkg("heroku-#{version}.pkg"), "heroku-toolbelt/heroku-toolbelt-#{version}.pkg"
  store pkg("heroku-#{version}.pkg"), "heroku-toolbelt/heroku-toolbelt-beta.pkg" if beta?
  store pkg("heroku-#{version}.pkg"), "heroku-toolbelt/heroku-toolbelt.pkg" unless beta?
end
