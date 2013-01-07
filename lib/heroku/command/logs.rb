require "heroku/command/base"

# display logs for an app
#
class Heroku::Command::Logs < Heroku::Command::Base

  # logs
  #
  # display recent log output
  #
  # -n, --num NUM        # the number of lines to display
  # -p, --ps PS          # only display logs from the given process
  # -s, --source SOURCE  # only display logs from the given source
  # -t, --tail           # continually stream logs
  #
  #Example:
  #
  # $ heroku logs
  # 2012-01-01T12:00:00+00:00 heroku[api]: Config add EXAMPLE by email@example.com
  # 2012-01-01T12:00:01+00:00 heroku[api]: Release v1 created by email@example.com
  #
  def index
    validate_arguments!

    opts = []
    opts << "tail=1"                                 if options[:tail]
    opts << "num=#{options[:num]}"                   if options[:num]
    opts << "ps=#{URI.encode(options[:ps])}"         if options[:ps]
    opts << "source=#{URI.encode(options[:source])}" if options[:source]

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

  # logs:drains
  #
  # DEPRECATED: use `heroku drains`
  #
  def drains
    # deprecation notice added 09/30/2011
    display("~ `heroku logs:drains` has been deprecated and replaced with `heroku drains`")
    Heroku::Command::Drains.new.index
  end

  protected

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
    return unless parsed = log.match(/^(.*?\[(\w+)([\d\.]+)?\]:)(.*)?$/)
    [1, 2, 4].map { |i| parsed[i] }
  end

end
