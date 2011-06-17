require "heroku/command/base"

module Heroku::Command

  # display logs for an app
  #
  class Logs < BaseWithApp

    # logs
    #
    # display recent log output
    #
    # -n, --num NUM        # the number of lines to display
    # -p, --ps PS          # only display logs from the given process
    # -s, --source SOURCE  # only display logs from the given source
    # -t, --tail           # continually stream logs
    #
    def index
      init_colors

      opts = []
      opts << "tail=1"                                 if options[:tail]
      opts << "num=#{options[:num]}"                   if options[:num]
      opts << "ps=#{URI.encode(options[:ps])}"         if options[:ps]
      opts << "source=#{URI.encode(options[:source])}" if options[:source]

      @line_start = true
      @token = nil

      $stdout.sync = true
      heroku.read_logs(app, opts) do |chk|
        next unless output = format_with_colors(chk)
        puts output
      end
    end

    # logs:cron
    #
    # DEPRECATED: display cron logs from legacy logging
    #
    def cron
      display heroku.cron_logs(app)
    end

    # logs:drains
    #
    # manage syslog drains
    #
    # logs:drains add URL     # add a syslog drain
    # logs:drains remove URL  # remove a syslog drain
    # logs:drains clear       # remove all syslog drains
    #
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

  protected

    def init_colors(colorizer=nil)
      if !colorizer && STDOUT.isatty
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

