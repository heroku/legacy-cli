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
        yield group
        group
      end
    end

    def self.create_default_groups!
      group 'General Commands' do |group|
        group.command 'help',                         'show this usage'
        group.command 'version',                      'show the gem version'
        group.space
        group.command 'list',                         'list your apps'
        group.command 'create [<name>]',              'create a new app'
        group.space
        group.command 'keys',                         'show your user\'s public keys'
        group.command 'keys:add [<path to keyfile>]', 'add a public key'
        group.command 'keys:remove <keyname> ',       'remove a key by name (user@host)'
        group.command 'keys:clear',                   'remove all keys'
        group.space
        group.command 'info',                         'show app info, like web url and git repo'
        group.command 'open',                         'open the app in a web browser'
        group.command 'rename <newname>',             'rename the app'
        group.space
        group.command 'dynos <qty>',                  'scale to qty web processes'
        group.command 'workers <qty>',                'scale to qty background processes'
        group.command 'ps',                           'show process list'
        group.space
        group.command 'sharing:add <email>',          'add a collaborator'
        group.command 'sharing:remove <email>',       'remove a collaborator'
        group.command 'sharing:transfer <email>',     'transfers the app ownership'
        group.space
        group.command 'domains:add <domain>',         'add a custom domain name'
        group.command 'domains:remove <domain>',      'remove a custom domain name'
        group.command 'domains:clear',                'remove all custom domains'
        group.space
        group.command 'ssl:add <pem> <key>',          'add SSL cert to the app'
        group.command 'ssl:remove <domain>',          'removes SSL cert from the app domain'
        group.command 'ssl:clear',                    'remove all SSL certs from the app'
        group.space
        group.command 'rake <command>',               'remotely execute a rake command'
        group.command 'console <command>',            'remotely execute a single console command'
        group.command 'console',                      'start an interactive console to the remote app'
        group.space
        group.command 'restart',                      'restart app servers'
        group.command 'logs',                         'fetch recent log output for debugging'
        group.command 'logs:cron',                    'fetch cron log output'
        group.space
        group.command 'maintenance:on',               'put the app into maintenance mode'
        group.command 'maintenance:off',              'take the app out of maintenance mode'
        group.space
        group.command 'config',                       'display the app\'s config vars (environment)'
        group.command 'config:add key=val [...]',     'add one or more config vars'
        group.command 'config:remove key [...]',      'remove one or more config vars'
        group.command 'config:clear',                 'clear user-set vars and reset to default'
        group.space
        group.command 'stack',                        'show current stack and list of available stacks'
        group.command 'stack:migrate',                'prepare migration of this app to a new stack'
        group.space
        group.command 'db:pull [<database_url>]',     'pull the app\'s database into a local database'
        group.command 'db:push [<database_url>]',     'push a local database into the app\'s remote database'
        group.command 'db:reset',                     'reset the database for the app'
        group.space
        group.command 'bundles',                      'list bundles for the app'
        group.command 'bundles:capture [<bundle>]',   'capture a bundle of the app\'s code and data'
        group.command 'bundles:download',             'download most recent app bundle as a tarball'
        group.command 'bundles:download <bundle>',    'download the named bundle'
        group.command 'bundles:destroy <bundle>',     'destroy the named bundle'
        group.space
        group.command 'addons',                       'list installed addons'
        group.command 'addons:info',                  'list all available addons'
        group.command 'addons:add name [key=value]',  'install addon (with zero or more config vars)'
        group.command 'addons:remove name',           'uninstall an addons'
        group.command 'addons:clear',                 'uninstall all addons'
        group.space
        group.command 'destroy',                      'destroy the app permanently'
      end

      group 'Plugins' do |group|
        group.command 'plugins',                      'list installed plugins'
        group.command 'plugins:install <url>',        'install the plugin from the specified git url'
        group.command 'plugins:uninstall <url/name>', 'remove the specified plugin'
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
