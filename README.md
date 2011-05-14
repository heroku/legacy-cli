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

Created by Adam Wiggins

Maintained by David Dollar

Patches contributed by:

* Adam McCrea <adam@edgecase.com>
* Adam Wiggins <adam@heroku.com>
* Ben <bwillis@teldio.com>
* Blake Mizerany <blake.mizerany@gmail.com>
* Caio Chassot <dev@caiochassot.com>
* Charles Roper <charles.roper@gmail.com>
* Chris O'Sullivan <thechrisoshow@gmail.com>
* Daniel Farina <daniel@heroku.com>
* David Dollar <ddollar@gmail.com>
* Denis Barushev <barushev@gmail.com>
* Eric Anderson <eric@pixelwareinc.com>
* Glenn Gillen <me@glenngillen.com>
* James Lindenbaum <james@heroku.com>
* Joshua Peek <josh@joshpeek.com>
* Julien Kirch <code@archiloque.net>
* Larry Marburger <larry@marburger.cc>
* Les Hill <leshill@gmail.com>
* Les Hill and Veez (Matt Remsik) <dev+leshill+veez@hashrocket.com>
* Mark McGranaghan <mmcgrana@gmail.com>
* Matt Buck <techpeace@gmail.com>
* Morten Bagai <morten@thefury.local>
* Nick Quaranto <nick@quaran.to>
* Noah Zoschke <noah@heroku.com>
* Pedro Belo <pedro@heroku.com>
* Peter Theill <peter@theill.com>
* Peter van Hardenberg <pvh@heroku.com>
* Ricardo Chimal, Jr <ricardo@heroku.com>
* Ryan R. Smith <ryan@heroku.com>
* Ryan Tomayko <rtomayko@gmail.com>
* Sarah Mei <sarah.mei@gmail.com>
* SixArm <sixarm@sixarm.com>
* Terence Lee <hone02@gmail.com>
* Trevor Turk <trevorturk@gmail.com>
* Will Leinweber <will@bitfission.com>
* pipa <tekmon@gmail.com>


Released under the [MIT license](http://www.opensource.org/licenses/mit-license.php).
