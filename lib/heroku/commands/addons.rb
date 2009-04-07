module Heroku::Command
	class Addons < Base
		def list
			addons = heroku.addons
			if addons.empty?
				display "No addons available currently"
			else
				app = extract_app(false)
				installed = app ? heroku.installed_addons(app) : []
				installed, available = addons.partition { |a| installed.include? a['name'] }
				unless installed.empty?
					display 'This app is using the following addons:'
					installed.each { |a| display '  ' + a['description'] }
					display ''
				end
				display 'Available addons:'
				available.each { |a| display '  ' + a['description'] }
			end
		end
		alias :index :list

		def add
			app = extract_app
			args.each do |name|
				display "Installing #{name} to #{app} ...", false
				display addon_run { heroku.install_addon(app, name) }
			end
		end

		def remove
			app = extract_app
			args.each do |name|
				display "Removing #{name} from #{app} ...", false
				display addon_run { heroku.uninstall_addon(app, name) }
			end
		end

		def clear
			app = extract_app
			heroku.installed_addons(app).each do |name|
				display "Removing #{name} from #{app} ...", false
				display addon_run { heroku.uninstall_addon(app, name) }
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