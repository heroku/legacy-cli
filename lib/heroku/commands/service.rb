module Heroku::Command
	class Service < Base
		def start
			app = extract_app
			attached = %w[--attached].any? { |name| args.delete(name) }
			if args.empty?
				display "Usage: heroku start [--attached] <command>"
			else
				command = args.join(' ')
				service = heroku.start(app, command, attached)
				service.each { |chunk| $stdout.write(chunk) } if attached
			end
		end

		def service(action)
			app = extract_app
			if args.empty?
				display "Usage: heroku #{action} <upid>..."
			else
				args.each do |upid|
					heroku.send(action, app, upid)
					display "#{action}: #{upid}"
				end
			end
		end

		def up     ; service('up')     ; end
		def down   ; service('down')   ; end
		def bounce ; service('bounce') ; end

		def status
			app  = extract_app
			services = heroku.status(app)

			if services.any?
				output = []
				output << "   UPID      SLUG       INST   COMMAND                     STATUS          SINCE"
				# display "-------  ------------  ------  --------------------------  ----------  ---------"
				services.reverse.each do |h|
					upid, instance, command = h[:upid], h[:instance], h[:command]
					status = h[:state]
					slug   = h[:slug].sub(/^\d+_/, '')
					since  = time_ago(h[:transitioned_at])
					output << "%7s  %12s  %6s  %-26s  %-10s  %9s" %
						[upid, slug, instance, truncate(command, 22), status, since]
				end
				puts output.join("\n")
			end
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
