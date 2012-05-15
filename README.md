Heroku CLI
==========

The Heroku CLI is used to manage Heroku apps from the command line.

For more about Heroku see <http://heroku.com>.

To get started see <http://devcenter.heroku.com/articles/quickstart>

[![Build Status](https://secure.travis-ci.org/heroku/heroku.png)](http://travis-ci.org/heroku/heroku)
[![Dependency Status](https://gemnasium.com/heroku/heroku.png)](https://gemnasium.com/heroku/heroku)

Setup
-----

<table>
  <tr>
    <th>If you have...</th>
    <th>Install with...</th>
  </tr>
  <tr>
    <td>Mac OS X</td>
    <td style="text-align: left"><a href="http://toolbelt.herokuapp.com/osx/download">Download OS X package</a></td>
  </tr>
  <tr>
    <td>Windows</td>
    <td style="text-align: left"><a href="http://toolbelt.herokuapp.com/windows/download">Download Windows .exe installer</a></td>
  </tr>
  <tr>
    <td>Ubuntu Linux</td>
    <td style="text-align: left"><a href="http://toolbelt.herokuapp.com/linux/readme"><code>apt-get</code> repository</a></td>
  </tr>
  <tr>
    <td>Other</td>
    <td style="text-align: left"><a href="http://assets.heroku.com/heroku-client/heroku-client.tgz">Tarball</a> (add contents to your <code>$PATH</code>)</td>
  </tr>
</table>

Once installed, you'll have access to the `heroku` command from your command shell.  Log in using the email address and password you used when creating your Heroku account:

    $ heroku login
    Enter your Heroku credentials.
    Email: adam@example.com
    Password:
    Could not find an existing public key.
    Would you like to generate one? [Yn]
    Generating new SSH public key.
    Uploading SSH public key /Users/adam/.ssh/id_rsa.pub

Press enter at the prompt to upload your existing `SSH` key or create a new one, used for pushing code later on.

API
---

Heroku API documentation can be found at <https://api-docs.heroku.com>

Development
-----------

If you're working on the CLI and you can smoke-test your changes:

    $ bundle exec heroku

Meta
----

Released under the MIT license; see the file License.

Created by Adam Wiggins

Maintained by Wesley Beary

[Other Contributors](https://github.com/heroku/heroku/contributors)
