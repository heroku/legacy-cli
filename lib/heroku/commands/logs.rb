module Heroku::Command
  class Logs < BaseWithApp
    Help.group("Logging (Expanded)") do |group|
      group.command "logs --tail",              "realtime logs tail"
      group.command "logs:drains",              "list syslog drains"
      group.command "logs:drains add <url>",    "add a syslog drain"
      group.command "logs:drains remove <url>", "remove a syslog drain"
      group.command "logs:drains clear",        "remove all syslog drains"
    end

    def index
      init_colors

      options = []
      until args.empty? do
        case args.shift
          when "-t", "--tail"   then options << "tail=1"
          when "-n", "--num"    then options << "num=#{args.shift.to_i}"
          when "-p", "--ps"     then options << "ps=#{URI.encode(args.shift)}"
          when "-s", "--source" then options << "source=#{URI.encode(args.shift)}"
          end
      end
      heroku.read_logs(app, options) do |chk|
        display_with_colors chk
      end
    end

    def cron
      display heroku.cron_logs(app)
    end

    def drains
      if args.empty?
        puts heroku.list_drains(app)
        return
      end

      case args.shift
        when "add"
          url = args.shift
          puts heroku.add_drain(app, url)
          return
        when "remove"
          url = args.shift
          puts heroku.remove_drain(app, url)
          return
        when "clear"
          puts heroku.clear_drains(app)
          return
      end
      raise(CommandFailed, "usage: heroku logs:drains <add | remove | clear>")
    end

    def init_colors
      require 'term/ansicolor'
      @assigned_colors = {}

      trap("INT") do
        puts Term::ANSIColor.reset
        exit
      end
    rescue LoadError
    end

    COLORS = %w( cyan yellow green magenta red )

    def display_with_colors(log)
      if !@assigned_colors
        puts log
        return
      end

      header, identifier, body = parse_log(log)
      return unless header
      @assigned_colors[identifier] ||= COLORS[@assigned_colors.size % COLORS.size]
      print Term::ANSIColor.send(@assigned_colors[identifier])
      print header
      print Term::ANSIColor.reset
      print body
      puts
    end

    def parse_log(log)
      return unless parsed = log.match(/^(.*\[(\w+)([\d\.]+)?\]:)(.*)?$/)
      [1, 2, 4].map { |i| parsed[i] }
    end
  end
end

