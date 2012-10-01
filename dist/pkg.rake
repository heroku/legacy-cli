require "erb"

file pkg("heroku-#{version}.pkg") => distribution_files("pkg") do |t|
  tempdir do |dir|
    mkchdir("heroku-client") do
      assemble_distribution
      assemble_gems
      assemble resource("pkg/heroku"), "bin/heroku", 0755
    end

    kbytes = %x{ du -ks heroku-client | cut -f 1 }
    num_files = %x{ find heroku-client | wc -l }

    mkdir_p "pkg"
    mkdir_p "pkg/Resources"
    mkdir_p "pkg/heroku-client.pkg"

    dist = File.read(resource("pkg/Distribution.erb"))
    dist = ERB.new(dist).result(binding)
    File.open("pkg/Distribution", "w") { |f| f.puts dist }

    dist = File.read(resource("pkg/PackageInfo.erb"))
    dist = ERB.new(dist).result(binding)
    File.open("pkg/heroku-client.pkg/PackageInfo", "w") { |f| f.puts dist }

    mkdir_p "pkg/heroku-client.pkg/Scripts"
    cp resource("pkg/postinstall"), "pkg/heroku-client.pkg/Scripts/postinstall"
    chmod 0755, "pkg/heroku-client.pkg/Scripts/postinstall"

    sh %{ mkbom -s heroku-client pkg/heroku-client.pkg/Bom }

    Dir.chdir("heroku-client") do
      sh %{ pax -wz -x cpio . > ../pkg/heroku-client.pkg/Payload }
    end

    sh %{ curl http://heroku-toolbelt.s3.amazonaws.com/ruby.pkg -o ruby.pkg }
    sh %{ pkgutil --expand ruby.pkg ruby }
    mv "ruby/ruby-1.9.3-p194.pkg", "pkg/ruby.pkg"

    sh %{ pkgutil --flatten pkg heroku-#{version}.pkg }

    cp_r "heroku-#{version}.pkg", t.name
  end
end

desc "build pkg"
task "pkg:build" => pkg("heroku-#{version}.pkg")

desc "clean pkg"
task "pkg:clean" do
  clean pkg("heroku-#{version}.pkg")
end

task "pkg:release" do
  raise "pkg:release moved to toolbelt repo"
end
