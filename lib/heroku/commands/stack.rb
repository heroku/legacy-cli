module Heroku::Command
	class Stack < BaseWithApp
		def list
			list = heroku.list_stacks(app)
			lines = list.map do |stack|
				if stack['current']
					"* #{stack['name']}"
				elsif stack['requested']
					"  #{stack['name']} (prepared, will migrate on next git push)"					
				else
					"  #{stack['name']}"
				end
			end
			display lines.join("\n")
		end
		alias :index :list

		def migrate
			display heroku.migrate_to_stack(app, args.shift.downcase)
		end
	end
end
