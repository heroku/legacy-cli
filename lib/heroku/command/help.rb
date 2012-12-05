require "heroku/command/base"
require "heroku/deprecated/help"

# list commands and display help
#
class Heroku::Command::Help < Heroku::Command::Base

  PRIMARY_NAMESPACES = %w( auth apps ps run addons config releases domains logs sharing )

  include Heroku::Deprecated::Help

  # help [COMMAND]
  #
  # list available commands or display help for a specific command
  #
  #Examples:
  #
  # $ heroku help
  # Usage: heroku COMMAND [--app APP] [command-specific-options]
  #
  # Primary help topics, type "heroku help TOPIC" for more details:
  #
  #   addons    #  manage addon resources
  #   apps      #  manage apps (create, destroy)
  #   ...
  #
  # Additional topics:
  #
  #   account      #  manage heroku account options
  #   accounts     #  manage multiple heroku accounts
  #   ...
  #
  # $ heroku help apps:create
  # Usage: heroku apps:create [NAME]
  #
  #  create a new app
  #
  #      --addons ADDONS        # a comma-delimited list of addons to install
  #  -b, --buildpack BUILDPACK  # a buildpack url to use for this app
  #  -r, --remote REMOTE        # the git remote to create, default "heroku"
  #  -s, --stack STACK          # the stack on which to create the app
  #
  def index
    if command = args.shift
      help_for_command(command)
    else
      help_for_root
    end
  end

  alias_command "-h", "help"
  alias_command "--help", "help"

private

  def commands_for_namespace(name)
    Heroku::Command.commands.values.select do |command|
      command[:namespace] == name && command[:command] != name
    end
  end

  def namespaces
    namespaces = Heroku::Command.namespaces
    namespaces.delete("app")
    namespaces
  end

  def commands
    Heroku::Command.commands
  end

  def legacy_help_for_namespace(namespace)
    instance = Heroku::Command::Help.groups.map do |group|
      [ group.title, group.select { |c| c.first =~ /^#{namespace}/ }.length ]
    end.sort_by { |l| l.last }.last
    return nil unless instance
    return nil if instance.last.zero?
    instance.first
  end

  def legacy_help_for_command(command)
    Heroku::Command::Help.groups.each do |group|
      group.each do |cmd, description|
        return description if cmd.split(" ").first == command
      end
    end
    nil
  end

  def skip_namespace?(ns)
    return true if ns[:description] =~ /DEPRECATED:/
    return true if ns[:description] =~ /HIDDEN:/
    false
  end

  def skip_command?(command)
    return true if command[:help] =~ /DEPRECATED:/
    return true if command[:help] =~ /HIDDEN:/
    false
  end

  def primary_namespaces
    PRIMARY_NAMESPACES.map { |name| namespaces[name] }.compact
  end

  def additional_namespaces
    (namespaces.values - primary_namespaces)
  end

  def summary_for_namespaces(namespaces)
    size = longest(namespaces.map { |n| n[:name] })
    namespaces.sort_by {|namespace| namespace[:name]}.each do |namespace|
      next if skip_namespace?(namespace)
      name = namespace[:name]
      namespace[:description] ||= legacy_help_for_namespace(name)
      puts "  %-#{size}s  # %s" % [ name, namespace[:description] ]
    end
  end

  def help_for_root
    puts "Usage: heroku COMMAND [--app APP] [command-specific-options]"
    puts
    puts "Primary help topics, type \"heroku help TOPIC\" for more details:"
    puts
    summary_for_namespaces(primary_namespaces)
    puts
    puts "Additional topics:"
    puts
    summary_for_namespaces(additional_namespaces)
    puts
  end

  def help_for_namespace(name)
    namespace_commands = commands_for_namespace(name)

    unless namespace_commands.empty?
      size = longest(namespace_commands.map { |c| c[:banner] })
      namespace_commands.sort_by { |c| c[:banner].to_s }.each do |command|
        next if skip_command?(command)
        command[:summary] ||= legacy_help_for_command(command[:command])
        puts "  %-#{size}s  # %s" % [ command[:banner], command[:summary] ]
      end
    end
  end

  def help_for_command(name)
    if command_alias = Heroku::Command.command_aliases[name]
      display("Alias: #{name} redirects to #{command_alias}")
      name = command_alias
    end
    if command = commands[name]
      puts "Usage: heroku #{command[:banner]}"

      if command[:help].strip.length > 0
        puts command[:help].split("\n")[1..-1].join("\n")
      else
        puts
        puts " " + legacy_help_for_command(name).to_s
      end
      puts
    end

    namespace_commands = commands_for_namespace(name).reject do |command|
      command[:help] =~ /DEPRECATED/
    end

    if !namespace_commands.empty?
      puts "Additional commands, type \"heroku help COMMAND\" for more details:"
      puts
      help_for_namespace(name)
      puts
    elsif command.nil?
      error "#{name} is not a heroku command. See `heroku help`."
    end
  end
end
