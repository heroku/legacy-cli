Heroku CLI Release Process
==========================

Releasing the CLI involves releasing a few different things. The important tasks can all be done on the buildserver.

## Releasing with buildserver

* Run test suite: `bundle exec rake`
* Update version number in `lib/heroku/version.rb` to `X.Y.Z`
  * Bump the patch level `Z` if the release contains bugfixes that do not change functionality
  * Bump the minor level `Y` if the release contains new functionality or changes to existing functionality
* Run `bundle install` to update the version of heroku in the `Gemfile.lock`
* Update `CHANGELOG`
* Commit the changes `git commit -m "vX.Y.Z" -a`
* Push changes to master `git push origin master`
* Go to the buildserver and release http://54.148.200.17/. [Here is the code for the buildserver.](https://github.com/heroku/toolbelt-build-server)
* [optional] Release the OSX pkg (instructions below)
* [optional] Release the WIN pkg (instructions below)

## Notes

The last 2 are optional because existing toolbelts will autoupdate after the first command is run. This isn't the case for deb packages which is why they're included in the main process. There can still be situations (although minor ones) where not releasing the osx/win packages can cause problems so they normally should always be run.

The release process will prevent you from releasing an already released version. If you have a bad/incomplete release, you may need to bump the version number again.

## Main Release

This process releases the tgz (standalone/homebrew), zip (for autoupdates), deb package and ruby gem. It's everything that is required to not end up with a partial release. This is what the buildserver does for you, so you shouldn't have to do this manually (this is just for reference). Because this builds a deb package, you must be on an Ubuntu box.

Prerequisites:

* Running from Ubuntu
* Make sure you have permissions to `heroku` gem through `gem` https://rubygems.org/gems/heroku.
* `HEROKU_RELEASE_ACCESS` and `HEROKU_RELEASE_SECRET`
* deb private key
* Ubuntu prerequisites:

```sh
echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
sudo apt-get install -y build-essential libpq-dev libsqlite3-dev curl xvfb wine
```

If this is your first time, you should first build the packages: `bundle exec rake build` Then look inside `./dist` to test each of the packages.

Once you are confident it works, release: `bundle exec rake release`. Note that release will automatically build if the packages are not there (there is no need to run `rake build`).

Note that you can look inside the `Rakefile` to test out each part of the step on your machine before it is built.

## OSX Release

Prerequisites:

* OSX
* Heroku Developer ID Installer Certificate in Keychain
* `HEROKU_RELEASE_ACCESS` and `HEROKU_RELEASE_SECRET`

To build for testing: `bundle exec rake pkg:build`. Outputs to `./dist/heroku-toolbelt-X.Y.Z.pkg`.
To release: `bundle exec rake pkg:release`.

## Windows Release

This is run not from a Windows machine, but from a UNIX machine with Wine.

Mac Prerequisites:

* Heroku Developer ID Installer Certificate in Keychain
* `HEROKU_RELEASE_ACCESS` and `HEROKU_RELEASE_SECRET`
* Install [XQuartz](http://xquartz.macosforge.org/) manually, or via the terminal (restart required):

```sh
curl -O# http://xquartz-dl.macosforge.org/SL/XQuartz-2.7.6.dmg
hdiutil attach XQuartz-2.7.6.dmg -mountpoint /Volumes/xquartz
sudo installer -store -pkg /Volumes/xquartz/XQuartz.pkg -target /
hdiutil detach /Volumes/xquartz
rm XQuartz-2.7.6.dmg
```

* `/opt/X11/bin` should be in your `$PATH` so `Xvfb` can be started.
* Install wine: `brew install wine`
* The pvk file:

The certificate and private key for code signing are in the repo in:

> dist/resources/exe/heroku-codesign-cert*

which is in the format mono signcode wants.

The pvk file is encrypted. If you want the build not to prompt you for
its passphrase, you'll need to decrypt it. See the `exe:pvk-nocrypt` task.

Bewake the openssl version on the Mac doesn't work with `exe:pvk-nocrypt`.
See comments on the source code for details and solution.

If you wanna leave the key encrypted, you still have to link it before
building; run the `exe:pvk` task for that.

You'll have to ask the right person for the passphrase to the key.

You then need to initialize a custom wine build environment. The `exe:init-wine`
task will do that for you.

To build for testing: `bundle exec rake exe:build`. Outputs to `./dist/heroku-toolbelt-X.Y.Z.exe`.
To release: `bundle exec rake pkg:release`.

## Ruby versions

Toolbelt bundles Ruby using different sources according to the OS:

- Windows: fetches [rubyinstaller.exe](http://rubyinstaller.org/) from S3.
- Mac: fetches ruby.pkg from S3. That file was extracted from
[RailsInstaller](http://railsinstaller.org/en).
- Linux: uses system debs for Ruby.

## Changelog (only if there is at least one major new feature)

* Create a [new changelog](http://devcenter.heroku.com/admin/changelog_items/new)
* Set the title to `Heroku CLI vX.Y.Z released with #{highlights}`
* Set the description to:

<!-- -->

    A new version of the Heroku CLI is available with #{details}.

    See the [CLI changelog](https://github.com/heroku/heroku/blob/master/CHANGELOG) for details and update by using `heroku update`.
