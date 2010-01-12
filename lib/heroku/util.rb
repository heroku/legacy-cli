class Heroku::Util

	def self.default_application_name
		base_command.extract_app
	rescue Heroku::Command::CommandFailed
		nil
	end

	def self.applications
		@applications ||= base_command.git_remotes(Dir.pwd).inject({}) do |hash, (remote, app)|
			hash.update(app => remote)
		end
	end

	def self.base_command
		@base_command ||= Heroku::Command::Base.new(ARGV)
	end

end
