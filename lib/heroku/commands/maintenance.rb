module Heroku::Command
	class Maintenance < BaseWithApp
		def on
			heroku.maintenance(app, :on)
		end

		def off
			heroku.maintenance(app, :off)
		end
	end
end
