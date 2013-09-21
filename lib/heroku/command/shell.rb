require "heroku/command/base"

# interactive shell for sequential commands
#
class Heroku::Command::Shell < Heroku::Command::Base

  # shell
  #
  # Read multiple commands
  #
  def index
    validate_arguments!

    begin
      app_or_nil = app
    rescue Heroku::Command::CommandFailed
      app_or_nil = nil
    end
    @cmd_tag = app_or_nil ? " (#{app_or_nil})" : ""

    require "readline"
    require "shellwords"

    sorted_commands = (Heroku::Command.commands.keys + Heroku::Command.command_aliases.keys).sort
    Readline.completion_append_character = " "
    Readline.completion_proc = proc { |s| sorted_commands.grep(/^#{Regexp.escape(s)}/) }

    while line = readline
      args = line.shellsplit
      next if args.empty?
      command = args.shift.strip
      return if command == "exit"
      args.unshift("--app", app_or_nil) if app_or_nil
      begin
        Heroku::Command.run(command, args)
      rescue SystemExit
      end
    end
    puts
  end

  private

  def readline
    begin
      return Readline.readline("heroku#{@cmd_tag}> ", true)
    rescue Interrupt
      puts
      retry
    end
  end

end
