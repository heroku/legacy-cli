Heroku CLI Release Process
==========================

This is the normal guide on how to do a release. If you are not a member of the CLI team and would like to release a new version of the CLI while they are out, this is the guide you want.

## Releasing with buildserver

* Run test suite: `bundle exec rake`
* Update version number in `lib/heroku/version.rb` to `X.Y.Z`
  * Bump the patch level `Z` if the release contains bugfixes that do not change functionality
  * Bump the minor level `Y` if the release contains new functionality or changes to existing functionality (bumping minor will also show a message to non-autoupdateable clients that a new version is out. Save these for either important releases, or features that need to go out.)
* Run `bundle install` to update the version of heroku in the `Gemfile.lock`
* Update `CHANGELOG`
* Commit the changes `git commit -m "vX.Y.Z" -a`
* Push changes to master `git push origin master`
* Go to the buildserver and release http://cli-build.herokai.com/. [Here is the code for the buildserver.](https://github.com/heroku/toolbelt-build-server)
* Run `heroku config:add` command in build output.
* [optional] Release the OSX pkg (instructions in [full release guide](./RELEASE-FULL.md))
* [optional] Release the WIN pkg (instructions in [full release guide](./RELEASE-FULL.md))

## When should the optional commands be run

Because the toolbelt autoupdates after the first command is run, not releasing those versions just means the user will be on the previously released version until they run a command, then they'll be on the latest even if OSX and Windows were not released.

For this reason, you can skip the OSX and Windows steps and probably should if you don't regularly release the CLI. This is because they involve getting a local environment setup to release the CLI and that is easier said than done.
