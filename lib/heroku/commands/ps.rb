module Heroku::Command
	class Ps < Base
		def index
			app = extract_app
			services = heroku.ps(app)

			services.sort! { |a,b| b[:transitioned_at] <=> a[:transitioned_at] }
			output = []
			output << "UPID     Slug          Inst    Command                     Status      Since"
			output << "-------  ------------  ------  --------------------------  ----------  ---------"
			services.each do |h|
				since = time_ago(h[:transitioned_at])
				output << "%-7s  %-12s  %-6s  %-26s  %-10s  %-9s" %
					[h[:upid], h[:slug], h[:instance], truncate(h[:command], 22), h[:state], since]
			end

			display output.join("\n")
		end

	private
		def time_ago(time)
			duration = Time.now - time
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
