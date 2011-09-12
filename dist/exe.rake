file pkg("heroku-#{version}.exe") => distribution_files("exe") do |t|
  tempdir do |dir|
    mkchdir("heroku-toolbelt") do
      assemble_distribution
      assemble_gems
      assemble resource("exe/heroku"), "heroku"
      assemble resource("exe/heroku.bat"), "heroku.bat"
    end

    FileUtils.rm_rf ("bin")

    File.open("heroku.iss", "w") do |iss|
      iss.write(ERB.new(File.read(resource("exe/heroku.iss"))).result(binding))
    end

    mkchdir("installers") do
      system "curl http://heroku-toolbelt.s3.amazonaws.com/rubyinstaller.exe -o rubyinstaller.exe"
      system "curl http://heroku-toolbelt.s3.amazonaws.com/git.exe -o git.exe"
    end

    inno_dir = ENV["INNO_DIR"] || 'C:\\Program Files (x86)\\Inno Setup 5\\'

    system "\"#{inno_dir}\\Compil32.exe\" /cc \"heroku.iss\""
  end
end

task "exe:build" => pkg("heroku-#{version}.exe")

task "exe:clean" do
  clean pkg("heroku-#{version}.exe")
end

task "exe:release" => "exe:build" do |t|
  store pkg("heroku-#{version}.exe"), "heroku-toolbelt/heroku-toolbelt-#{version}.exe"
  store pkg("heroku-#{version}.exe"), "heroku-toolbelt/heroku-toolbelt-beta.exe" if beta?
  store pkg("heroku-#{version}.exe"), "heroku-toolbelt/heroku-toolbelt.exe" unless beta?
end
