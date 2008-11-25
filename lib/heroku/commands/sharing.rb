module Heroku::Command
	class Sharing < BaseWithApp
		def list
			list = heroku.list_collaborators(app)
			display list.map { |c| "#{c[:email]} (#{c[:access]})" }.join("\n")
		end
		alias :index :list

		def add
			email = args.shift.downcase rescue nil
			display heroku.add_collaborator(app, email, 'edit')
		end

		def remove
			email = args.shift.downcase rescue nil
			heroku.remove_collaborator(app, email)
			display "Collaborator removed."
		end
	end
end