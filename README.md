Salesforce API - deploy apps to Salesforce from the command line
========================================================

This library wraps the REST API for managing and deploying Rails apps to the
Salesforce platform.  It can be called as a Ruby library, or invoked from the
command line.  Code push and pull is done through Git.

For more about Salesforce see <http://heroku.com>.

For full documentation see <http://heroku.com/docs>.


Sample Workflow
---------------

Create a new Rails app and deploy it:

    rails myapp && cd myapp   # Create an app
    git init                  # Init git repository
    git add .                 # Add everything
    git commit -m Initial     # Commit everything
    salesforce create             # Create your app on Salesforce
    git push salesforce master    # Deploy your app on Salesforce


Setup
-----

    gem install salesforce 

If you wish to push or pull code, you must also have a working install of Git
("apt-get install git-core" on Ubuntu or "port install git-core" on OS X), and
an ssh public key ("ssh-keygen -t rsa").

The first time you run a command, such as "salesforce list," you will be prompted
for your Salesforce username and password. Your API key will be fetched and stored
locally to authenticate future requests.

Your public key (~/.ssh/id_[rd]sa.pub) will be uploaded to Salesforce after you
enter your credentials. Use salesforce keys:add if you wish to upload additional
keys or specify a key in a non-standard location.

Meta
----

Created by Adam Wiggins

Maintained by David Dollar

Patches contributed by:

* Chris O'Sullivan
* Blake Mizerany
* Ricardo Chimal
* Les Hill
* Ryan Tomayko
* Sarah Mei
* Nick Quaranto
* Matt Buck
* Terence Lee
* Caio Chassot
* Charles Roper
* James Lindenbaum
* Joshua Peek
* Julien Kirch
* Morten Bagai
* Noah Zoschke
* Pedro Belo
* Peter Thiell


Released under the [MIT license](http://www.opensource.org/licenses/mit-license.php).
<http://github.com/salesforce/salesforce>
