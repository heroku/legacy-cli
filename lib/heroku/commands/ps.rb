module Heroku::Command
  class Ps < Base
    def index
      app = extract_app
      ps = heroku.ps(app)

      output = []
      output << "Process       State               Command"
      output << "------------  ------------------  ------------------------------"

      ps.sort_by do |p|
        t,n = p['process'].split(".")
        [t, n.to_i]
      end.each do |p|
        output << "%-12s  %-18s  %s" %
          [ p['process'], "#{p['state']} for #{time_ago(p['elapsed']).gsub(/ ago/, '')}", truncate(p['command'], 36) ]
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
