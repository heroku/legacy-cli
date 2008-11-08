module Heroku::Command
	class Sharing < Base
		def list
			name = extract_app
			list = heroku.list_collaborators(name)
			display list.map { |c| "#{c[:email]} (#{c[:access]})" }.join("\n")
		end
		alias :index :list

		def add
			name = extract_app
			email = args.shift.downcase rescue nil
			display heroku.add_collaborator(name, email, 'edit')
		end

		def remove
			name = extract_app
			email = args.shift.downcase rescue nil
			heroku.remove_collaborator(name, email)
			display "Collaborator removed"
		end
	end
end