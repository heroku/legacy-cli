module Heroku::Command
	class Ps < Base
		def index
			ps = heroku.ps(extract_app)

			output = []
			output << "UPID     Slug          Command                     State       Since"
			output << "-------  ------------  --------------------------  ----------  ---------"

			ps.sort! { |a,b| b['transitioned_at'] <=> a['transitioned_at'] }
			ps.each do |p|
				since = time_ago(p['transitioned_at'])
				output << "%-7s  %-12s  %-26s  %-10s  %-9s" %
					[p['upid'], p['slug'], truncate(p['command'], 22), p['state'], since]
			end

			display output.join("\n")
		end

	private
		def time_ago(time)
			duration = Time.now - Time.parse(time)
			if duration < 60
				"#{duration.floor}s ago"
			elsif duration < (60 * 60)
				"#{(duration / 60).floor}m ago"
			else
				"#{(duration / 60 / 60).floor}h ago"
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
