require "heroku/helpers"

module Heroku::Helpers
  class LogDisplayer

    include Heroku::Helpers

    attr_reader :heroku, :app, :opts

    def initialize(heroku, app, opts)
      @heroku, @app, @opts = heroku, app, opts
    end

    def display_logs
      @assigned_colors = {}
      @line_start = true
      @token = nil

      heroku.read_logs(app, opts) do |chunk|
        unless chunk.empty?
          if STDOUT.isatty && ENV.has_key?("TERM")
            display(colorize(chunk))
          else
            display(chunk)
          end
        end
      end
    rescue Errno::EPIPE
    rescue Interrupt => interrupt
      if STDOUT.isatty && ENV.has_key?("TERM")
        display("\e[0m")
      end
      raise(interrupt)
    end

    COLORS = %w( cyan yellow green magenta red )
    COLOR_CODES = {
      "red"     => 31,
      "green"   => 32,
      "yellow"  => 33,
      "magenta" => 35,
      "cyan"    => 36,
    }

    def colorize(chunk)
      lines = []
      chunk.split("\n").map do |line|
        if parsed_line = parse_log(line)
          header, identifier, body = parsed_line
          @assigned_colors[identifier] ||= COLORS[@assigned_colors.size % COLORS.size]
          lines << [
            "\e[#{COLOR_CODES[@assigned_colors[identifier]]}m",
            header,
            "\e[0m",
            body,
          ].join("")
        elsif not line.empty?
          lines << line
        end
      end
      lines.join("\n")
    end

    def parse_log(log)
      return unless parsed = log.match(/^(.*?\[([\w-]+)([\d\.]+)?\]:)(.*)?$/)
      [1, 2, 4].map { |i| parsed[i] }
    end

  end
end
