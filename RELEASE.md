Heroku CLI Release Process
==========================

### Ensure tests are passing

* `bundle exec rake spec`

### Prepare new version

* Update version number in `lib/heroku/version.rb` to `X.Y.Z`
  * Bump the patch level `Z` if the release contains bugfixes that do not change functionality
  * Bump the minor level `Y` if the release contains new functionality or changes to existing functionality
* Run `bundle install` to update the version of heroku in the Gemfile.lock
* Update `CHANGELOG`
* Commit the changes `git commit -m "vX.Y.Z" -a`

### Release the gem

* Ask @ddollar for:
  * Permissions to Rubygems.org
  * Access to the `toolbelt` Heroku app
  * `HEROKU_RELEASE_ACCESS` and `HEROKU_RELEASE_SECRET` config var values (export values in terminal)
  * Access and permissions to run builds on http://dx-jenkins.herokai.com/
* Release the gem `bundle exec rake release`

### Release the toolbelt

* Move to a checkout of the toolbelt repo and make sure everything is up to date `git pull`
  - If this is a new checkout, run `git submodule init` and `git submodule update`
* Move to the components/heroku directory, `git fetch` and `git reset --hard HASH` where HASH is commit hash of vX.Y.Z
* Move back to the root dir of the toolbelt repo, stage `git add .`, commit `git commit -m "bump heroku submodule to vX.Y.Z"`, and push `git push` submodule changes
* Start toolbelt-build build at http://dx-jenkins.herokai.com/ (this will be opened by rake release automatically)

### Changelog (only if there is at least one major new feature)

* Create a [new changelog](http://devcenter.heroku.com/admin/changelog_items/new)
* Set the title to `Heroku CLI vX.Y.Z released with #{highlights}`
* Set the description to:

<!-- -->

    A new version of the Heroku CLI is available with #{details}.

    See the [CLI changelog](https://github.com/heroku/heroku/blob/master/CHANGELOG) for details and update by using `heroku update`.
