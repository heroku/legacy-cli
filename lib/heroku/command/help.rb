require "heroku/command/base"

module Heroku::Command

  # show this help
  #
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
        commands[new][:banner] = "#{new} #{commands[new][:banner].split(" ", 2)[1]}"
        commands[new][:command] = new
        commands[new][:namespace] = nil
      end
      commands
    end

    def legacy_help_for_namespace(namespace)
      instance = Heroku::Command::Help.groups.map do |group|
        [ group.title, group.select { |c| c.first =~ /^#{namespace}/ }.length ]
      end.sort_by(&:last).last
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

    PRIMARY_NAMESPACES = %w( auth apps ps run addons config releases domains logs sharing )

    def primary_namespaces
      PRIMARY_NAMESPACES.map { |name| namespaces[name] }.compact
    end

    def additional_namespaces
      (namespaces.values - primary_namespaces).sort_by { |n| n[:name] }
    end

    def summary_for_namespaces(namespaces)
      size = longest(namespaces.map { |n| n[:name] })
      namespaces.each do |namespace|
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
          next if command[:help] =~ /DEPRECATED/
          command[:summary] ||= legacy_help_for_command(command[:command])
          puts "  %-#{size}s  # %s" % [ command[:banner], command[:summary] ]
        end
      end
    end

    def help_for_command(name)
      command = commands[name]

      if command
        if command[:help].strip.length > 0
          puts "Usage: heroku #{command[:banner]}"
          puts command[:help].split("\n")[1..-1].join("\n")
          puts
        else
          puts "Usage: heroku #{command[:banner]}"
          puts
          puts " " + legacy_help_for_command(name).to_s
          puts
        end
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
