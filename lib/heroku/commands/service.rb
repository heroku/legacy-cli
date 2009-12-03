module Heroku::Command
	class Service < Base
		def start
			display "heroku service:start is defunct.  Use heroku workers +1 instead."
		end

		def up
			display "heroku service:up is defunct.  Use heroku workers +1 instead."
		end

		def down
			display "heroku service:start is defunct.  Use heroku workers -1 instead."
		end

		def bounce
			display "heroku service:start is defunct.  Use heroku restart instead."
		end

		def status
			display "heroku service:status is defunct.  Use heroku ps instead."
		end
	end
end
