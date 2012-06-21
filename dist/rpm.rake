# TODO
# * signing
# * yum repository for updates
# * foreman

file pkg("/yum-#{version}/heroku-#{version}.rpm") => "deb:build" do |t|
  mkchdir(File.dirname(t.name)) do
    deb = pkg("/apt-#{version}/heroku-#{version}.deb")
    sh "alien --keep-version --scripts --generate --to-rpm #{deb}"

    spec = "heroku-#{version}/heroku-#{version}-1.spec"
    spec_contents = File.read(spec)
    File.open(spec, "w") do |f|
      # Add ruby requirement, remove benchmark file with ugly filename
      f.puts spec_contents.sub(/\n\n/m, "\nRequires: ruby\nBuildArch: noarch\n\n").
        sub(/^.+has_key-vs-hash\[key\].+$/, "").
        sub(/^License: .*/, "License: MIT\nURL: http://heroku.com\n").
        sub(/^%description/, "%description\nClient library and CLI to deploy apps on Heroku.")
    end
    sh "sed -i s/ruby1.9.1/ruby/ heroku-#{version}/usr/local/heroku/bin/heroku"

    chdir("heroku-#{version}") do
      sh "rpmbuild --buildroot $PWD -bb heroku-#{version}-1.spec"
    end
  end
end

desc "Build an .rpm package"
task "rpm:build" => pkg("/yum-#{version}/heroku-#{version}.rpm")

desc "Remove build artifacts for .rpm"
task "rpm:clean" do
  clean pkg("heroku-#{version}.rpm")
  FileUtils.rm_rf("pkg/yum-#{version}") if Dir.exists?("pkg/yum-#{version}")
end
