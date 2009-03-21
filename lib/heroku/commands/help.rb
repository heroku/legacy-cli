module Heroku::Command
	class Help < Base
		def index
			display usage
		end

		def usage
			usage = <<EOTXT

=== General Commands

 help                         # show this usage
 version                      # show the gem version

 list                         # list your apps
 create [<name>]              # create a new app

 keys                         # show your user's public keys
 keys:add [<path to keyfile>] # add a public key
 keys:remove <keyname>        # remove a key by name (user@host)
 keys:clear                   # remove all keys

=== App Commands (execute inside a checkout directory, or use --app <appname>)

 info                         # show app info, like web url and git repo
 open                         # open the app in a web browser
 rename <newname>             # rename the app

 sharing:add <email>          # add a collaborator
 sharing:remove <email>       # remove a collaborator

 domains:add <domain>         # add a custom domain name
 domains:remove <domain>      # remove a custom domain name
 domains:clear                # remove all custom domains

 rake <command>               # remotely execute a rake command
 console <command>            # remotely execute a single console command
 console                      # start an interactive console to the remote app

 restart                      # restart app servers
 logs                         # fetch recent log output for debugging
 logs:cron                    # fetch cron log output

 db:pull <database_url>       # pull the app's database into a local database
 db:push <database_url>       # push a local database into the app's remote database
 db:reset                     # reset the database for the app

 bundles                      # list bundles for the app
 bundles:capture [<bundle>]   # capture a bundle of the app's code and data
 bundles:download             # download most recent app bundle as a tarball
 bundles:download <bundle>    # download the named bundle
 bundles:animate <bundle>     # animate a bundle into a new app
 bundles:destroy <bundle>     # destroy the named bundle

 destroy                      # destroy the app permanently

=== Example:

 rails myapp
 cd myapp
 git init
 git add .
 git commit -m "my new app"
 heroku create myapp
 git push heroku master

EOTXT
		end
	end
end
