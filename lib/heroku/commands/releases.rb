require "heroku/commands/help"

module Heroku::Command
  Help.group("Releases") do |group|
    group.command "releases",                 "list releases"
    group.command "releases:info <release>",  "detailed info for a release"
    group.command "rollback [<release>]",     "roll back to a prior release"
  end

  class Releases < Base
    def index
      releases = heroku.releases(extract_app)

      output = []
      output << "Rel   Change                          By                    When"
      output << "----  ----------------------          ----------            ----------"

      releases.reverse.slice(0, 15).each do |r|
        name = r["name"]
        descr = truncate(r["descr"], 30)
        user = truncate(r["user"], 20)
        time_ago = delta_format(Time.parse(r["created_at"]))
        output << "%-4s  %-30s  %-20s  %-25s" % [name, descr, user, time_ago]
      end

      display output.join("\n")
    end

    def info
      release = args.shift.downcase.strip rescue nil
      raise(CommandFailed, "Specify a release") unless release

      release = heroku.release(extract_app, release)

      display "=== Release #{release['name']}"
      display_info("Change",  release["descr"])
      display_info("By",      release["user"])
      display_info("When",    delta_format(Time.parse(release["created_at"])))
      display_info("Addons",  release["addons"].join(", "))
      display_vars(release["env"])
    end

    private

    def pluralize(str, n)
      n == 1 ? str : "#{str}s"
    end

    def delta_format(start, finish = Time.now)
      secs  = (finish.to_i - start.to_i).abs
      mins  = (secs/60).round
      hours = (mins/60).round
      days  = (hours/24).round
      if days > 0
        start.to_s
      elsif hours > 0
        "#{hours} #{pluralize("hour", hours)} ago"
      elsif mins > 0
        "#{mins} #{pluralize("minute", mins)} ago"
      else
        "#{secs} #{pluralize("second", secs)} ago"
      end
    end

    def truncate(text, length)
      (text.size > length) ? text[0, length - 3] + "..." : text
    end

    def display_info(label, info)
      display(format("%-12s %s", "#{label}:", info))
    end

    def display_vars(vars)
      max_length = vars.map { |v| v[0].size }.max

      first = true
      lead = "Config:"

      vars.keys.sort.each do |key|
        spaces = ' ' * (max_length - key.size)
        display "#{first ? lead : ' ' * lead.length}      #{key}#{spaces} => #{vars[key]}"
        first = false
      end
    end
  end

  class Rollback < Base
    def index
      app = extract_app
      release = args.shift.downcase.strip rescue nil
      rolled_back = heroku.rollback(app, release)
      display "Rolled back to #{rolled_back}"
    end
  end
end
