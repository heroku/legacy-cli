module Heroku::Command
	class Logs < Base
		def index
			app_name = extract_app
			display heroku.logs(app_name)
		end

		def cron
			app_name = extract_app
			display heroku.cron_logs(app_name)
		end
	end
end