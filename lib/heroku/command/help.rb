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
  def index
    if command = args.shift
      help_for_command(command)
    else
      help_for_root
    end
  end

  alias_command "-h", "help"
  alias_command "--help", "help"

  def self.usage_for_command(command)
    command = new.send(:commands)[command]
    "Usage: heroku #{command[:banner]}" if command
  end

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
    commands = Heroku::Command.commands
    Heroku::Command.command_aliases.each do |new, old|
      commands[new] = commands[old].dup
      commands[new][:command] = new
      commands[new][:namespace] = nil
      commands[new][:alias_for] = old
    end
    commands
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

  def primary_namespaces
    PRIMARY_NAMESPACES.map { |name| namespaces[name] }.compact
  end

  def additional_namespaces
    (namespaces.values - primary_namespaces)
  end

  def summary_for_namespaces(namespaces)
    size = longest(namespaces.map { |n| n[:name] })
    namespaces.sort_by {|namespace| namespace[:name]}.each do |namespace|
      name = namespace[:name]
      namespace[:description] ||= legacy_help_for_namespace(name)
      display "  %-#{size}s  # %s" % [ name, namespace[:description] ]
    end
  end

  def help_for_root
    display "Usage: heroku COMMAND [--app APP] [command-specific-options]"
    display
    display "Primary help topics, type \"heroku help TOPIC\" for more details:"
    display
    summary_for_namespaces(primary_namespaces)
    display
    display "Additional topics:"
    display
    summary_for_namespaces(additional_namespaces)
    display
  end

  def help_for_namespace(name)
    namespace_commands = commands_for_namespace(name)

    unless namespace_commands.empty?
      size = longest(namespace_commands.map { |c| c[:banner] })
      namespace_commands.sort_by { |c| c[:banner].to_s }.each do |command|
        next if command[:help] =~ /DEPRECATED/
        command[:summary] ||= legacy_help_for_command(command[:command])
        display "  %-#{size}s  # %s" % [ command[:banner], command[:summary] ]
      end
    end
  end

  def help_for_command(name)
    command = commands[name]

    if command
      display "Usage: heroku #{command[:banner]}"

      if command[:help].strip.length > 0
        display command[:help].split("\n")[1..-1].join("\n")
      else
        display
        display " " + legacy_help_for_command(name).to_s
      end
      display
    end

    if commands_for_namespace(name).size > 0
      display "Additional commands, type \"heroku help COMMAND\" for more details:"
      display
      help_for_namespace(name)
      display
    elsif command.nil?
      error "#{name} is not a heroku command. See 'heroku help'."
    end
  end
end
