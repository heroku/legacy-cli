module Heroku::PluginInterface

	def self.included(base)
		base.extend Heroku::PluginInterface
	end

	def default_application_name
		base_command.extract_app
	rescue Heroku::Command::CommandFailed
		nil
	end

	def applications
		@applications ||= (base_command.git_remotes(Dir.pwd) || []).inject({}) do |hash, (remote, app)|
			hash.update(app => remote)
		end
	end

	def base_command
		@base_command ||= Heroku::Command::Base.new(ARGV)
	end

	def command(command, *args)
		Heroku::Command.run_internal command.to_s, args
	end
end
