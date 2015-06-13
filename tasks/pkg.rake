file dist("heroku-toolbelt-#{version}.pkg") => distribution_files("pkg") do |t|
  tempdir do |dir|
    mkdir "heroku-client"
    cd "heroku-client" do
      assemble_distribution
      assemble_gems
      assemble resource("pkg/heroku"), "bin/heroku", 0755
    end

    mkdir_p "pkg"
    mkdir_p "pkg/Resources"
    mkdir_p "pkg/heroku-client.pkg"

    kbytes = %x{ du -ks pkg | cut -f 1 }
    num_files = %x{ find pkg | wc -l }

    dist = File.read(resource("pkg/Distribution.erb"))
    dist = ERB.new(dist).result(binding)
    File.open("pkg/Distribution", "w") { |f| f.puts dist }

    dist = File.read(resource("pkg/PackageInfo.erb"))
    dist = ERB.new(dist).result(binding)
    File.open("pkg/heroku-client.pkg/PackageInfo", "w") { |f| f.puts dist }

    mkdir_p "pkg/Scripts"

    mkdir_p "pkg/heroku-client.pkg/Scripts"
    cp resource("pkg/postinstall"), "pkg/heroku-client.pkg/Scripts/postinstall"
    chmod 0755, "pkg/heroku-client.pkg/Scripts/postinstall"

    sh %{ mkbom -s heroku-client pkg/heroku-client.pkg/Bom }

    Dir.chdir("heroku-client") do
      sh %{ find . | cpio -o --format odc | gzip -c > ../pkg/heroku-client.pkg/Payload }
    end

    unless File.exists?(dist('ruby.pkg'))
      sh %{ curl https://heroku-toolbelt.s3.amazonaws.com/ruby.pkg -o #{dist('ruby.pkg')} }
    end
    sh %{ pkgutil --expand #{dist('ruby.pkg')} ruby }
    mv "ruby/ruby-1.9.3-p194.pkg", "pkg/ruby.pkg"

    sh %{ pkgutil --flatten pkg heroku-toolbelt-#{version}.pkg }
    sh %{ productsign --sign "Developer ID Installer: Heroku INC" heroku-toolbelt-#{version}.pkg heroku-toolbelt-#{version}-signed.pkg }
    cp_r "heroku-toolbelt-#{version}-signed.pkg", t.name
  end
end

desc "build pkg"
task "pkg:build" => dist("heroku-toolbelt-#{version}.pkg")

desc "release pkg"
task "pkg:release" => dist("heroku-toolbelt-#{version}.pkg") do
  s3_store dist("heroku-toolbelt-#{version}.pkg"), "heroku-toolbelt/heroku-toolbelt-#{version}.pkg"
  s3_store dist("heroku-toolbelt-#{version}.pkg"), "heroku-toolbelt/heroku-toolbelt-beta.pkg" if beta?
  s3_store dist("heroku-toolbelt-#{version}.pkg"), "heroku-toolbelt/heroku-toolbelt.pkg" unless beta?
end
