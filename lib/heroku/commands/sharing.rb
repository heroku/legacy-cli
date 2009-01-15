module Heroku::Command
	class Sharing < BaseWithApp
		def list
			list = heroku.list_collaborators(app)
			display list.map { |c| "#{c[:email]} (#{c[:access]})" }.join("\n")
		end
		alias :index :list

		def add
			email = args.shift.downcase rescue ''
			raise(CommandFailed, "Specify an email address to share the app with.") if email == ''
			display heroku.add_collaborator(app, email)
		end

		def remove
			email = args.shift.downcase rescue ''
			raise(CommandFailed, "Specify an email address to remove from the app.") if email == ''
			heroku.remove_collaborator(app, email)
			display "Collaborator removed."
		end
	end
end
