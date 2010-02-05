module Heroku::Command
  class Ps < Base
    def index
      ps = heroku.ps(extract_app)

      output = []
      output << "UPID     Slug          Command                     State       Since"
      output << "-------  ------------  --------------------------  ----------  ---------"

      ps.each do |p|
        output << "%-7s  %-12s  %-26s  %-10s  %-9s" %
          [p['upid'], p['slug'], truncate(p['command'], 22), p['state'], time_ago(p['elapsed'])]
      end

      display output.join("\n")
    end

  private
    def time_ago(elapsed)
      if elapsed < 60
        "#{elapsed.floor}s ago"
      elsif elapsed < (60 * 60)
        "#{(elapsed / 60).floor}m ago"
      else
        "#{(elapsed / 60 / 60).floor}h ago"
      end
    end

    def truncate(text, length)
      if text.size > length
        text[0, length - 2] + '..'
      else
        text
      end
    end
  end
end
