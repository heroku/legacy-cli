require "heroku"
require "heroku/command"

class Heroku::CLI

  def self.start(*args)
    begin
      command = args.shift.strip rescue "help"
      Heroku::Command.load
      Heroku::Command.run(command, args)
    rescue Interrupt
      `stty icanon echo`
      puts("\n !    Command cancelled.")
    end
  end

end
