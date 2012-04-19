require "heroku/command/base"

module Heroku::Command

  # view release history of an app
  #
  class Releases < Base

    # releases
    #
    # list releases
    #
    def index
      releases = heroku.releases(app)

      objects = []
      releases.reverse.slice(0, 15).sort_by do |release|
        release["name"]
      end.reverse.each do |release|
        objects << {
          "by"      => truncate(release["user"], 20),
          "change"  => truncate(release["descr"], 30),
          "rel"     => release["name"],
          "when"    => time_ago(Time.now.to_i - Time.parse(release["created_at"]).to_i)
        }
      end

      display_table(
        objects,
        ["rel", "change", "by", "when"],
        ["Rel", "Change", "By", "When"]
      )
    end

    # releases:info RELEASE
    #
    # view detailed information for a release
    #
    def info
      release = args.shift.downcase.strip rescue nil
      raise(CommandFailed, "Specify a release") unless release

      release = heroku.release(app, release)

      display "=== Release #{release['name']}"
      display_info("Change",  release["descr"])
      display_info("By",      release["user"])
      display_info("When",    time_ago(Time.now.to_i - Time.parse(release["created_at"]).to_i))
      display_info("Addons",  release["addons"].join(", "))
      display_vars(release["env"])
    end

    # releases:rollback [RELEASE]
    #
    # roll back to an older release
    #
    # if RELEASE is not specified, will roll back one step
    #
    def rollback
      release = args.shift.downcase.strip rescue nil
      rolled_back = heroku.rollback(app, release)
      display "Rolled back to #{rolled_back}"
    end

    alias_command "rollback", "releases:rollback"

    private

    def pluralize(str, n)
      n == 1 ? str : "#{str}s"
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
end
