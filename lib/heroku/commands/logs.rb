require "heroku/commands/help"

module Heroku::Command
  Heroku::Command::Help.group("Logging (Expanded)") do |group|
    group.command "logs --tail",              "realtime logs tail"
    group.command "logs:drains",              "list syslog drains"
    group.command "logs:drains add <url>",    "add a syslog drain"
    group.command "logs:drains remove <url>", "remove a syslog drain"
    group.command "logs:drains clear",        "remove all syslog drains"
  end

  class Logs < BaseWithApp
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

      @line_start = true
      @token = nil

      heroku.read_logs(app, options) do |chk|
        next unless output = format_with_colors(chk)
        puts output
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

    def init_colors(colorizer=nil)
      if !colorizer
        require 'term/ansicolor'
        @colorizer = Term::ANSIColor
      else
        @colorizer = colorizer
      end

      @assigned_colors = {}

      trap("INT") do
        puts @colorizer.reset
        exit
      end
    rescue LoadError
    end

    COLORS = %w( cyan yellow green magenta red )

    def format_with_colors(chunk)
      return if chunk.empty?
      return chunk unless @colorizer

      chunk.split("\n").map do |line|
        header, identifier, body = parse_log(line)
        @assigned_colors[identifier] ||= COLORS[@assigned_colors.size % COLORS.size]
        [
          @colorizer.send(@assigned_colors[identifier]),
          header,
          @colorizer.reset,
          body,
        ].join("")
      end.join("\n")
    end

    def parse_log(log)
      return unless parsed = log.match(/^(.*\[(\w+)([\d\.]+)?\]:)(.*)?$/)
      [1, 2, 4].map { |i| parsed[i] }
    end
  end
end

