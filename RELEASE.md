Heroku CLI Release Process
==========================

### Ensure tests are passing
* Ensure CI is passing `bundle exec rake ci`
* Ensure fisticuffs passes by starting a build at http://dx-jenkins.herokai.com/, you can open with `bundle exec rake jenkins`

### Prepare new version
* Update version number in `lib/heroku/version.rb` to X.Y.Z
* Run `bundle install` to update the version of heroku in the Gemfile.lock
* Update `CHANGELOG`
* Commit the changes `git commit -m "vX.Y.Z"` -a

### Release the gem
* Release the gem `bundle exec rake release`

### Release the toolbelt
* Move to a checkout of the toolbelt repo and make sure everything is up to date `git pull`
* Move to the components/heroku directory, `git fetch` and `git reset --hard HASH` where HASH is commit hash of vX.Y.Z
* Stage `git add .`, commit `git commit -m "bump heroku submodule to vX.Y.Z"`, and push `git push` submodule changes
* Start toolbelt-build build at http://dx-jenkins.herokai.com/ (this will be opened by rake release automatically)

### Changelog (only if there is at least one major new feature)

* Create a [new changelog] => http://devcenter.heroku.com/admin/changelog_items/new, you can open with `bundle exec rake changelog`
* Paste the contents of your clipboard (or enter text based on the following):
* Set the title to `Heroku CLI vX.Y.Z released with #{highlights}`
* Set the description to:

<!-- -->

    A new version of the Heroku CLI is available with #{details}.

    See the [CLI changelog](https://github.com/heroku/heroku/blob/master/CHANGELOG) for details and update by using `heroku update`.
