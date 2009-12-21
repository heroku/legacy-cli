module Heroku::Command
	class Help < Base
		class HelpGroup < Array
			attr_reader :title

			def initialize(title)
				@title = title
			end

			def command(name, description)
				self << [name, description]
			end

			def space
				self << ['', '']
			end
		end

		def self.groups
			@groups ||= []
		end

		def self.group(title, &block)
			groups << begin
				group = HelpGroup.new(title)
				group.instance_eval(&block)
				group
			end
		end

		def self.create_default_groups!
			group('General Commands') do
				command 'help',                         'show this usage'
				command 'version',                      'show the gem version'
				space
				command 'list',                         'list your apps'
				command 'create [<name>]',              'create a new app'
				space
				command 'keys',                         'show your user\'s public keys'
				command 'keys:add [<path to keyfile>]', 'add a public key'
				command 'keys:remove <keyname> ',       'remove a key by name (user@host)'
				command 'keys:clear',                   'remove all keys'
				space
				command 'info',                         'show app info, like web url and git repo'
				command 'open',                         'open the app in a web browser'
				command 'rename <newname>',             'rename the app'
				space
				command 'dynos <qty>',                  'scale to qty web processes'
				command 'workers <qty>',                'scale to qty background processes'
				space
				command 'sharing:add <email>',          'add a collaborator'
				command 'sharing:remove <email>',       'remove a collaborator'
				command 'sharing:transfer <email>',     'transfers the app ownership'
				space
				command 'domains:add <domain>',         'add a custom domain name'
				command 'domains:remove <domain>',      'remove a custom domain name'
				command 'domains:clear',                'remove all custom domains'
				space
				command 'ssl:add <pem> <key>',          'add SSL cert to the app'
				command 'ssl:remove <domain>',          'removes SSL cert from the app domain'
				space
				command 'rake <command>',               'remotely execute a rake command'
				command 'console <command>',            'remotely execute a single console command'
				command 'console',                      'start an interactive console to the remote app'
				space
				command 'restart',                      'restart app servers'
				command 'logs',                         'fetch recent log output for debugging'
				command 'logs:cron',                    'fetch cron log output'
				space
				command 'maintenance:on',               'put the app into maintenance mode'
				command 'maintenance:off',              'take the app out of maintenance mode'
				space
				command 'config',                       'display the app\'s config vars (environment)'
				command 'config:add key=val [...]',     'add one or more config vars'
				command 'config:remove key [...]',      'remove one or more config vars'
				command 'config:clear',                 'clear user-set vars and reset to default'
				space
				command 'db:pull [<database_url>]',     'pull the app\'s database into a local database'
				command 'db:push [<database_url>]',     'push a local database into the app\'s remote database'
				command 'db:reset',                     'reset the database for the app'
				space
				command 'bundles',                      'list bundles for the app'
				command 'bundles:capture [<bundle>]',   'capture a bundle of the app\'s code and data'
				command 'bundles:download',             'download most recent app bundle as a tarball'
				command 'bundles:download <bundle>',    'download the named bundle'
				command 'bundles:animate <bundle>',     'animate a bundle into a new app'
				command 'bundles:destroy <bundle>',     'destroy the named bundle'
				space
				command 'addons',                       'list installed addons'
				command 'addons:info',                  'list all available addons'
				command 'addons:add name [key=value]',  'install addon (with zero or more config vars)'
				command 'addons:remove name',           'uninstall an addons'
				command 'addons:clear',                 'uninstall all addons'
				space
				command 'destroy',                      'destroy the app permanently'
			end

			group('Plugins') do
				command 'plugins',                      'list installed plugins'
				command 'plugins:install <url>',        'install the plugin from the specified git url'
				command 'plugins:uninstall <url/name>', 'remove the specified plugin'
			end
		end

		def index
			display usage
		end

		def version
			display Heroku::Client.version
		end

		def usage
			longest_command_length = self.class.groups.map do |group|
				group.map { |g| g.first.length }
			end.flatten.max

			self.class.groups.inject(StringIO.new) do |output, group|
				output.puts "=== %s" % group.title
				output.puts

				group.each do |command, description|
					if command.empty?
						output.puts
					else
						output.puts "%-*s # %s" % [longest_command_length, command, description]
					end
				end

				output.puts
				output
			end.string + <<-EOTXT
=== Example:

 rails myapp
 cd myapp
 git init
 git add .
 git commit -m "my new app"
 heroku create
 git push heroku master

EOTXT
		end
	end
end

Heroku::Command::Help.create_default_groups!
