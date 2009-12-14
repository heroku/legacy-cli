module Heroku::Command
	class Plugins < Base
		def list
			::Heroku::Plugin.list.each do |plugin|
				display plugin
			end
		end
		alias :index :list

		def install
			plugin = Heroku::Plugin.new(args.shift)
			plugin.install
			display "#{plugin} installed"
		end

		def uninstall
			plugin = Heroku::Plugin.new(args.shift)
			plugin.uninstall
			display "#{plugin} uninstalled"
		end
	end
end
