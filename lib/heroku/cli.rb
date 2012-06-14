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
    rescue => error
      puts(' !    Error encountered.')
      puts(" !    You can search for help at: https://help.heroku.com")
      puts(" !    Or report this as a bug at: https://github.com/heroku/heroku/issues/new")
      puts
      puts("    Error:     #{error.message} (#{error.class})")
      puts("    Backtrace: #{error.backtrace.first}")
      error.backtrace[1..-1].each do |line|
        puts("               #{line}")
      end
      puts
      command = ARGV.map do |arg|
        if arg.include?(' ')
          arg = %{"#{arg}"}
        else
          arg
        end
      end.join(' ')
      puts("    Command:   heroku #{command}")
      puts("    Version:   #{Heroku::USER_AGENT}")
      puts
    end
  end

end
