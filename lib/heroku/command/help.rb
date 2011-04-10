require "heroku/command/base"

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
      return if @defaults_created
      @defaults_created = true
      group 'General Commands' do |group|
        group.command 'help',                         'show this usage'
        group.command 'version',                      'show the gem version'
        group.space
        group.command 'login',                        'log in with your heroku credentials'
        group.command 'logout',                       'clear local authentication credentials'
        group.space
        group.command 'list',                         'list your apps'
        group.command 'create [<name>]',              'create a new app'
        group.command 'info',                         'show app info, like web url and git repo'
        group.command 'open',                         'open the app in a web browser'
        group.command 'rename <newname>',             'rename the app'
        group.command 'destroy',                      'destroy the app permanently'
        group.space
        group.command 'dynos <qty>',                  'scale to qty web processes'
        group.command 'workers <qty>',                'scale to qty background processes'
        group.command 'console <command>',            'remotely execute a single console command'
        group.command 'console',                      'start an interactive console to the remote app'
        group.command 'rake <command>',               'remotely execute a rake command'
        group.command 'ps',                           'show process list'
        group.command 'restart',                      'restart app processes'
        group.space
        group.command 'addons',                       'list installed addons'
        group.command 'addons:info',                  'list all available addons'
        group.command 'addons:add name [key=value]',  'install addon (with zero or more config vars)'
        group.command 'addons:remove name',           'uninstall an addon'
        group.command 'addons:clear',                 'uninstall all addons'
        group.command 'addons:open name',             'open an addon\'s page in your browser'
        group.space
        group.command 'config',                       'display the app\'s config vars (environment)'
        group.command 'config:add key=val [...]',     'add one or more config vars'
        group.command 'config:remove key [...]',      'remove one or more config vars'
        group.space
        group.command 'db:pull [<database_url>]',     'pull the app\'s database into a local database'
        group.command 'db:push [<database_url>]',     'push a local database into the app\'s remote database'
        group.space
        group.command 'domains:add <domain>',         'add a custom domain name'
        group.command 'domains:remove <domain>',      'remove a custom domain name'
        group.command 'domains:clear',                'remove all custom domains'
        group.space
        group.command 'keys',                         'show your user\'s public keys'
        group.command 'keys:add [<path to keyfile>]', 'add a public key'
        group.command 'keys:remove <keyname> ',       'remove a key by name (user@host)'
        group.command 'keys:clear',                   'remove all keys'
        group.space
        group.command 'ssl:add <pem> <key>',          'add SSL cert to the app'
        group.command 'ssl:remove <domain>',          'removes SSL cert from the app domain'
        group.command 'ssl:clear',                    'remove all SSL certs from the app'
        group.space
        group.command 'logs',                         'fetch recent log output for debugging'
        group.command 'logs:cron',                    'fetch cron log output'
        group.space
        group.command 'maintenance:on',               'put the app into maintenance mode'
        group.command 'maintenance:off',              'take the app out of maintenance mode'
        group.space
        group.command 'sharing:add <email>',          'add a collaborator'
        group.command 'sharing:remove <email>',       'remove a collaborator'
        group.command 'sharing:transfer <email>',     'transfers the app ownership'
        group.space
        group.command 'stack',                        'show current stack and list of available stacks'
        group.command 'stack:migrate',                'prepare migration of this app to a new stack'
        group.space
      end

      group 'Plugins' do |group|
        group.command 'plugins',                      'list installed plugins'
        group.command 'plugins:install <url>',        'install the plugin from the specified git url'
        group.command 'plugins:uninstall <url/name>', 'remove the specified plugin'
      end
    end

    def index
      if command = args.shift
        help_for_command(command)
      else
        help_for_root
      end
    end

  private

    def commands_for_namespace(name)
      Heroku::Command.commands.values.select do |command|
        command[:namespace] == name && command[:method] != :index
      end
    end

    def namespaces
      namespaces = Heroku::Command.namespaces
      namespaces.delete("app")
      namespaces
    end

    def commands
      commands = Heroku::Command.commands
    end

    def longest(items)
      items.map(&:to_s).map(&:length).sort.last
    end

    def legacy_help_for_namespace(namespace)
      instance = Heroku::Command::Help.groups.map do |group|
        [ group.title, group.select { |c| c.first =~ /^#{namespace}/ }.length ]
      end.sort_by(&:last).last
      instance.last.zero? ? nil : instance.first
    end

    def legacy_help_for_command(command)
      Heroku::Command::Help.groups.each do |group|
        group.each do |cmd, description|
          return description if cmd.split(" ").first == command
        end
      end
      nil
    end

    def help_for_root
      puts "Usage: heroku COMMAND"
      puts
      help_for_namespace(nil)
      puts
      puts "Additional commands, type \"heroku help GROUP\" for more details:"
      puts
      size = longest(namespaces.values.map { |n| n[:name] })
      namespaces.sort_by(&:first).each do |name, namespace|
        namespace[:description] ||= legacy_help_for_namespace(name)
        puts "  %-#{size}s  # %s" % [ name, namespace[:description] ]
      end
      puts
    end

    def help_for_namespace(name)
      namespace_commands = commands_for_namespace(name)

      unless namespace_commands.empty?
        size = longest(namespace_commands.map { |c| c[:banner] })
        namespace_commands.sort_by { |c| c[:method] }.each do |command|
          command[:summary] ||= legacy_help_for_command(command[:command])
          puts "  %-#{size}s  # %s" % [ command[:banner], command[:summary] ]
        end
      end
    end

    def help_for_command(name)
      command = commands[name]

      if command
        if command[:help].strip.length > 0
          print "Usage: heroku "
          puts command[:help]
          puts
        else
          puts "Usage: heroku #{command[:banner]}"
          puts
          puts legacy_help_for_command(name)
          puts
        end

        unless commands_for_namespace(name).empty?
          puts "Additional commands, type \"heroku help COMMAND\" for more details:"
          puts
          help_for_namespace(name)
          puts
        end
      end
    end
  end
end

Heroku::Command::Help.create_default_groups!
