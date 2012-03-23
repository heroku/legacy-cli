Heroku CLI Release Process
==========================

* Ensure CI is passing `bundle exec rake ci`
* Update version number in `/lib/heroku/version.rb` to X.Y.Z
* Run `bundle install` to update the version of heroku in the Gemfile.lock
* Update changelog.txt
* Commit these changes `git commit vX.Y.Z` and push them `git push origin master`
* Ensure CI still passes `bundle exec rake ci`
* Release the gem `bundle exec rake gem:release`
* Update the submodule in toolbelt/components/heroku `git fetch` and `git reset --hard HASH` where HASH is commit hash of vX.Y.Z
* add `git add .`, commit `git commit -m "bump heroku submodule to vX.Y.Z"`, and push `git push` submodule changes
* Ask in #dx for toolbelt releases
* Update [devcenter changelog](http://devcenter.heroku.com/changelog)
