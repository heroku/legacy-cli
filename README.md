Heroku API - deploy apps to Heroku from the command line
========================================================

This library wraps the REST API for managing and deploying Rails apps to the
Heroku platform.  It can be called as a Ruby library, or invoked from the
command line.  Code push and pull is done through Git.

For more about Heroku see <http://heroku.com>.

For full documentation see <http://heroku.com/docs>.


Sample Workflow
---------------

Create a new Rails app and deploy it:

    rails myapp && cd myapp   # Create an app
    git init                  # Init git repository
    git add .                 # Add everything
    git commit -m Initial     # Commit everything
    heroku create             # Create your app on Heroku
    git push heroku master    # Deploy your app on Heroku


Setup
-----

    gem install heroku

If you wish to push or pull code, you must also have a working install of Git
("apt-get install git-core" on Ubuntu or "port install git-core" on OS X), and
an ssh public key ("ssh-keygen -t rsa").

The first time you run a command, such as "heroku list," you will be prompted
for your Heroku username and password. Your API key will be fetched and stored
locally to authenticate future requests.

Your public key (~/.ssh/id_[rd]sa.pub) will be uploaded to Heroku after you
enter your credentials. Use heroku keys:add if you wish to upload additional
keys or specify a key in a non-standard location.

Meta
----

Released under the [MIT license](http://www.opensource.org/licenses/mit-license.php).

Created by Adam Wiggins

Maintained by David Dollar

Patches contributed by:

* Adam
* Adam Dusk
* Adam McCrea
* Adam Wiggins
* Alex Dowad
* Ben
* Blake Mizerany
* Caio Chassot
* Charles Roper
* Chris Continanza
* Chris O'Sullivan
* Daniel Farina
* Daniel Vartanov
* David Dollar
* Denis Barushev
* Eric Anderson
* Gabriel Horner
* Glenn Gillen
* Jacob Vorreuter
* James Lindenbaum
* Jonathan Dance
* Joshua Peek
* Julien Kirch
* Larry Marburger
* Les Hill
* Les Hill and Veez (Matt Remsik)
* Mark McGranaghan
* Matt Buck
* Matt Manning
* Matthew M. Boedicker
* Morten Bagai
* Nick Quaranto
* Noah Zoschke
* Pedro Belo
* Peter Theill
* Peter van Hardenberg
* Ricardo Chimal, Jr
* Ryan R. Smith
* Ryan Tomayko
* Sarah Mei
* SixArm
* Terence Lee
* Trevor Turk
* Will Leinweber
* bmizerany
* pipa
