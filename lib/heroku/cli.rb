require "heroku"
require "heroku/command"
require "heroku/helpers"

class Heroku::CLI

  extend Heroku::Helpers

  def self.start(*args)
    begin
      command = args.shift.strip rescue "help"
      Heroku::Command.load
      Heroku::Command.run(command, args)
    rescue Interrupt
      `stty icanon echo`
      error("Command cancelled.")
    rescue => error
      if Heroku::Helpers.error_with_failure
        display("failed")
        Heroku::Helpers.error_with_failure = false
      end
      $stderr.puts(' !    Heroku client internal error.')
      $stderr.puts(" !    Search for help at: https://help.heroku.com")
      $stderr.puts(" !    Or report a bug at: https://github.com/heroku/heroku/issues/new")
      $stderr.puts
      $stderr.puts("    Error:       #{error.message} (#{error.class})")
      $stderr.puts("    Backtrace:   #{error.backtrace.first}")
      error.backtrace[1..-1].each do |line|
        $stderr.puts("                 #{line}")
      end
      $stderr.puts
      command = ARGV.map do |arg|
        if arg.include?(' ')
          arg = %{"#{arg}"}
        else
          arg
        end
      end.join(' ')
      $stderr.puts("    Command:     heroku #{command}")
      unless Heroku::Auth.host == Heroku::Auth.default_host
        $stderr.puts("    Host:        #{Heroku::Auth.host}")
      end
      if http_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']
        $stderr.puts("    HTTP Proxy:  #{http_proxy}")
      end
      if https_proxy = ENV['https_proxy'] || ENV['HTTPS_PROXY']
        $stderr.puts("    HTTPS Proxy: #{https_proxy}")
      end
      $stderr.puts("    Version:     #{Heroku::USER_AGENT}")
      $stderr.puts
      exit(1)
    end
  end

end
