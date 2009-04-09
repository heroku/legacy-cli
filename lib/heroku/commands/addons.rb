module Heroku::Command
	class Addons < BaseWithApp
		def list
			addons = heroku.addons
			if addons.empty?
				display "No addons available currently"
			else
				installed = heroku.installed_addons(app)
				available = addons.select { |a| !installed.include? a }

				display 'Activated addons:'
				if installed.empty?
					display '  (none)'
				else
					installed.each { |a| display '  ' + a['description'] }
				end

				display ''
				display 'Available addons:'
				available.each { |a| display '  ' + a['description'] }
			end
		end
		alias :index :list

		def add
			args.each do |name|
				display "Installing #{name} to #{app} ...", false
				display addon_run { heroku.install_addon(app, name) }
			end
		end

		def remove
			args.each do |name|
				display "Removing #{name} from #{app} ...", false
				display addon_run { heroku.uninstall_addon(app, name) }
			end
		end

		def clear
			heroku.installed_addons(app).each do |addon|
				display "Removing #{addon['description']} from #{app} ...", false
				display addon_run { heroku.uninstall_addon(app, addon['name']) }
			end
		end

		private
			def addon_run
				yield
				'Done'
			rescue RestClient::ResourceNotFound => e
				'Failed! Addon not found'
			rescue RestClient::RequestFailed => e
				'Failed! Internal Server Error'
			end
	end
end
