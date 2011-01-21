module Heroku
  module Helpers
    def home_directory
      running_on_windows? ? ENV['USERPROFILE'] : ENV['HOME']
    end

    def running_on_windows?
      RUBY_PLATFORM =~ /mswin32|mingw32/
    end

    def running_on_a_mac?
      RUBY_PLATFORM =~ /-darwin\d/
    end

    def display(msg, newline=true)
      if newline
        puts(msg)
      else
        print(msg)
        STDOUT.flush
      end
    end

    def redisplay(line, line_break = false)
      display("\r\e[0K#{line}", line_break)
    end

    def deprecate(version)
      display "!!! DEPRECATION WARNING: This command will be removed in version #{version}"
      display ""
    end

    def error(msg)
      STDERR.puts(msg)
      exit 1
    end

    def confirm(message="Are you sure you wish to continue? (y/n)?")
      display("#{message} ", false)
      ask.downcase == 'y'
    end

    def confirm_command(app = app)
      if extract_option('--force')
        display("Warning: The --force switch is deprecated, and will be removed in a future release. Use --confirm #{app} instead.")
        return true
      end

      raise(Heroku::Command::CommandFailed, "No app specified.\nRun this command from app folder or set it adding --app <app name>") unless app

      confirmed_app = extract_option('--confirm', false)
      if confirmed_app
        unless confirmed_app == app
          raise(Heroku::Command::CommandFailed, "Confirmed app #{confirmed_app} did not match the selected app #{app}.")
        end
        return true
      else
        display ""
        display " !    WARNING: Potentially Destructive Action"
        display " !    This command will affect the app: #{app}"
        display " !    To proceed, type \"#{app}\" or re-run this command with --confirm #{app}"
        display ""
        display "> ", false
        if ask.downcase != app
          display " !    Input did not match #{app}. Aborted."
          false
        else
          true
        end
      end
    end

    def format_date(date)
      date = Time.parse(date) if date.is_a?(String)
      date.strftime("%Y-%m-%d %H:%M %Z")
    end

    def ask
      gets.strip
    end

    def shell(cmd)
      FileUtils.cd(Dir.pwd) {|d| return `#{cmd}`}
    end

    def run_command(command, args=[])
      Heroku::Command.run_internal(command, args)
    end

    def retry_on_exception(*exceptions)
      retry_count = 0
      begin
        yield
      rescue *exceptions => ex
        raise ex if retry_count >= 3
        sleep 3
        retry_count += 1
        retry
      end
    end
  end
end

unless String.method_defined?(:shellescape)
  class String
    def shellescape
      empty? ? "''" : gsub(/([^A-Za-z0-9_\-.,:\/@\n])/n, '\\\\\\1').gsub(/\n/, "'\n'")
    end
  end
end
