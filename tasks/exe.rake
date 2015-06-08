require "erb"
require "shellwords"

$is_mac     = RUBY_PLATFORM =~ /darwin/
$base_path  = File.expand_path(File.join(File.dirname(__FILE__), ".."))
$cache_path = File.join($base_path, "dist", "cache")
def windows_path(path); `winepath -w #{path.shellescape}`.chomp; end

def setup_wine_env
  ENV["WINEPREFIX"]       = "#$base_path/dist/wine" # keep it contained; by default it goes in $HOME/.wine
  ENV["WINEDEBUG"]        = "-all"                  # wine is full of errors, no one cares
  ENV["WINEDLLOVERRIDES"] = "winemenubuilder.exe=n" # tell wine to use our custom winemenubuilder.exe, see comment in exe:init-wine
  ENV["DISPLAY"]          = ':42'
  $xvfb_pid = spawn 'Xvfb', ':42', [:out,:err] => '/dev/null' # use a virtual x server so we can run headless
  sleep(2) # give Xvfb some time to boot up
end

def cleanup_after_wine
  # terminate our Xvfb process
  sleep(2) # give Xvfb some time to finish up; seems to prevent some error messages
  Process.kill "INT", $xvfb_pid
  Process.wait $xvfb_pid
  # wine leaves the terminal all sorts of broken.
  # pretty much every time it'll switch input to cursor key application mode (cf. http://www.tldp.org/HOWTO/Keyboard-and-Console-HOWTO-21.html),
  # fairly often it'll turn echo off, a couple other odd things have also been observed.
  # this sends a soft reset to the terminal, albeit I suspect it only works in xterm emulators,
  # but then again maybe it's an xterm-only problem anyway? who knows…
  system "echo \033[!p"
  system "stty echo"
end

# ensure cleanup_after_wine runs when aborted too
trap("INT") { cleanup_after_wine; exit }

# see comment on build_zip
def extract_zip(filename, destination)
  tempdir do |dir|
    sh %{ unzip -q "#{filename}" }
    sh %{ mv * "#{destination}" }
  end
end

# a bunch of needed binaries are in an amazon bucket. not sure I love this, but I guess it keeps the repo small
def cache_file_from_bucket(filename)
  FileUtils.mkdir_p $cache_path
  file_cache_path = File.join($cache_path, filename)
  system "curl -# https://heroku-toolbelt.s3.amazonaws.com/#{filename} -o '#{file_cache_path}'" unless File.exists? file_cache_path
  file_cache_path
end

# file task for the final windows installer file.
# if you ask me, it's fairly pointless to be using a file task for the final
# file if the intermediates get placed in all sorts of temp dirs that then get
# destroyed, so we don't get to benefit from the time savings of not generating
# the same thing over and over again.
file dist("heroku-toolbelt-#{version}.exe") => "zip:build" do |exe_task|
  tempdir do |build_path|
    installer_path = "#{build_path}/heroku-installer"
    heroku_cli_path = "#{installer_path}/heroku"
    mkdir_p heroku_cli_path
    extract_zip "#{$base_path}/dist/heroku-#{version}.zip", "#{heroku_cli_path}/"

    # gather the ruby and git installers, downlading from s3
    mkdir "#{installer_path}/installers"
    cd "#{installer_path}/installers" do
      ["rubyinstaller.exe", "git.exe"].each { |i| cp cache_file_from_bucket(i), i }
    end

    # add windows helper executables to the heroku cli
    cp resource("exe/heroku.bat"),  "#{heroku_cli_path}/bin/heroku.bat"
    cp resource("exe/heroku"),      "#{heroku_cli_path}/bin/heroku"
    cp resource("exe/foreman.bat"), "#{heroku_cli_path}/bin/foreman.bat"
    cp resource("exe/foreman"),     "#{heroku_cli_path}/bin/foreman"
    cp resource("exe/ssh-keygen.bat"), "#{heroku_cli_path}/bin/ssh-keygen.bat"

    # render the iss file used by inno setup to compile the installer
    # this sets the version and the output filename
    File.write("#{installer_path}/heroku.iss", ERB.new(File.read(resource("exe/heroku.iss"))).result(binding))

    # the codesign command used by inno to sign the installer and uninstaller
    sign_cmd = 'c:\windows\mono\mono-2.0\lib\mono\4.5\signcode.exe' + %Q[
      -spc "#{windows_path(resource('exe/heroku-codesign-cert.spc'))}"
      -v   "#{windows_path(resource('exe/heroku-codesign-cert.pvk'))}"
      -a   sha1 -$ commercial
      -n   "Heroku Toolbelt"
      $f ].            # $f gets replaced by iscc with the path to the file it wants to compile
      gsub("\n", ' '). # everything on a single line now
      gsub('"', '$q') # iscc requires quotes to be escaped this way, don't ask

    # compile installer under wine!
    setup_wine_env
    system 'wine', 'C:\inno\ISCC.exe',
      "/Smono-signcode=#{sign_cmd}", '/qp',
      windows_path("#{installer_path}/heroku.iss")
    cleanup_after_wine

    # move final installer from build_path to pkg dir
    mv File.basename(exe_task.name), exe_task.name
  end
end

desc "Build exe"
task "exe:build" => dist("heroku-toolbelt-#{version}.exe")

desc "Release exe"
task "exe:release" => "exe:build" do |t|
  s3_store dist("heroku-toolbelt-#{version}.exe"), "heroku-toolbelt/heroku-toolbelt-#{version}.exe"
  s3_store dist("heroku-toolbelt-#{version}.exe"), "heroku-toolbelt/heroku-toolbelt-beta.exe" if beta?
  s3_store dist("heroku-toolbelt-#{version}.exe"), "heroku-toolbelt/heroku-toolbelt.exe" unless beta?
end

desc "Create wine environment to build windows installer"
task "exe:init-wine" do
  setup_wine_env
  rm_rf ENV["WINEPREFIX"]
  system "wineboot --init" # init wine dir
  # replace winemenubuilder with a thing that does nothing, preventing it from poopin' a .config dir into your $HOME
  system %q[
    echo "int main(){return 0;}" > noop.c
    winegcc noop.c -o noop
    mv noop.exe.so "$WINEPREFIX/drive_c/windows/system32/winemenubuilder.exe"
    rm noop.*
  ]
  # set mac wine to use the x11 display driver; iscc borks without this, also it lets us run headless with Xvfb
  system %Q[echo '[HKEY_CURRENT_USER\\Software\\Wine\\Drivers]\n"Graphics"="x11"' | regedit -] if $is_mac
  # install inno setup
  isetup_path = windows_path(cache_file_from_bucket("isetup.exe")).shellescape
  system "wine #{isetup_path} /verysilent /suppressmsgboxes /nocancel /norestart /noicons /dir=c:\\inno"
  cleanup_after_wine
end

# Mono's signcode tool can't take the private key passphrase non-interactively (i.e. read file, or as a parameter), so
# in order to run the build non-interactively we have to use a passphrase-less key. To keep the private key secure, the
# key that comes from the repository is encrypted. You can either run exe:build and type in the passphrase manually
# (twice!), or decode it for good with this task.
#
# Ensure your build environment is secure before leaving an unencrypted private key lying around.
#
# Additionally, Mac OS X's default openssl, as of Mavericks, is 0.9.8y, which doesn't support the pvk format. The 1.0.x
# tree does, and you can install it via homebrew (brew install openssl), but it's keg-only, so it'll not be in your
# PATH. You could `brew link` it, but it's safer to leave it alone. Instead, you can pass the full path to the openssl
# binary to be used via the OPENSSL_PATH environment variable:
#
#    OPENSSL_PATH=`brew --prefix openssl`/bin/openssl rake exe:pvk-nocrypt
desc "Remove passphrase from heroku-codesign-cert.pvk; see source comments"
task "exe:pvk-nocrypt" do
  openssl = (ENV["OPENSSL_PATH"] || "openssl").shellescape
  version = `#{openssl} version`.chomp
  keyfile_in  = resource('exe/heroku-codesign-cert.encrypted.pvk').shellescape
  keyfile_out = resource('exe/heroku-codesign-cert.pvk').shellescape
  raise "OpenSSL version should be 1.0.x; instead got: #{version}" if version !~ /^OpenSSL 1\./
  system "#{openssl} rsa -inform PVK -outform PVK -pvk-none -in #{keyfile_in} -out #{keyfile_out}"
end

desc "Link the encrypted pvk"
task "exe:pvk" do
  symlink resource("exe/heroku-codesign-cert.encrypted.pvk"), resource("exe/heroku-codesign-cert.pvk")
end
