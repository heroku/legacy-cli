Heroku CLI Release Process
==========================

* Ensure CI is passing `bundle exec rake ci`
* Update changelog.txt and [devcenter changelog](http://devcenter.heroku.com/changelog)
* Update version number in `/lib/heroku/version.rb`
* Run `bundle install` to update the version of heroku in the Gemfile.lock
* Commit these changes `git commit vX.Y.Z` and push them `git push origin master`
* Ensure CI still passes `bundle exec rake ci`
* Release the gem `bundle exec rake gem:release`
* Update the submodule in toolbelt `git submodule update --init --recursive`
* Ask in #dx for toolbelt releases.
