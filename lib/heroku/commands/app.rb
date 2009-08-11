require 'readline'
require 'launchy'

module Heroku::Command
	class App < Base
		def list
			list = heroku.list
			if list.size > 0
				display list.join("\n")
			else
				display "You have no apps."
			end
		end

		def create
			remote  = extract_option('--remote', 'heroku')
			name    = args.shift.downcase.strip rescue nil
			name    = heroku.create(name, {})
			display "Created #{app_urls(name)}"
			if remote || File.exists?(Dir.pwd + '/.git')
				remote ||= 'heroku'
				return if shell('git remote').split("\n").include?(remote)
				shell "git remote add #{remote} git@#{heroku.host}:#{name}.git"
				display "Git remote #{remote} added"
			end
		end

		def rename
			name    = extract_app
			newname = args.shift.downcase.strip rescue ''
			raise(CommandFailed, "Invalid name.") if newname == ''

			heroku.update(name, :name => newname)
			display app_urls(newname)

			if remotes = git_remotes(Dir.pwd)
				remotes.each do |remote_name, remote_app|
					next if remote_app != name
					shell "git remote rm #{remote_name}"
					shell "git remote add #{remote_name} git@#{heroku.host}:#{newname}.git"
					display "Git remote #{remote_name} updated"
				end
			else
				display "Don't forget to update your Git remotes on any local checkouts."
			end
		end

		def info
			name = (args.first && !args.first =~ /^\-\-/) ? args.first : extract_app
			attrs = heroku.info(name)
			display "=== #{attrs[:name]}"
			display "Web URL:        http://#{attrs[:name]}.#{heroku.host}/"
			display "Domain name:    http://#{attrs[:domain_name]}/" if attrs[:domain_name]
			display "Git Repo:       git@#{heroku.host}:#{attrs[:name]}.git"
			display "Repo size:      #{format_bytes(attrs[:repo_size])}" if attrs[:repo_size]
			display "Slug size:      #{format_bytes(attrs[:slug_size])}" if attrs[:slug_size]
			if attrs[:database_size]
				data = format_bytes(attrs[:database_size])
				if tables = attrs[:database_tables]
					data = data.gsub('(empty)', '0K') + " in #{tables} table#{'s' if tables.to_i > 1}"
				end
				display "Data size:      #{data}"
			end

			unless attrs[:addons].empty?
				display "Addons:         " + attrs[:addons].map { |a| a['description'] }.join(', ')
			end

			display "Owner:          #{attrs[:owner]}"
			collaborators = attrs[:collaborators].delete_if { |c| c[:email] == attrs[:owner] }
			unless collaborators.empty?
				first = true
				lead = "Collaborators:"
				attrs[:collaborators].each do |collaborator|
					display "#{first ? lead : ' ' * lead.length}  #{collaborator[:email]}"
					first = false
				end
			end
		end

		def open
			app = extract_app

			url = web_url(app)
			puts "Opening #{url}"
			Launchy.open url
		end

		def rake
			app = extract_app
			cmd = args.join(' ')
			if cmd.length == 0
				display "Usage: heroku rake <command>"
			else
				heroku.start(app, "rake #{cmd}", attached=true).each do |chunk|
					display chunk, false
				end
			end
		rescue Heroku::Client::AppCrashed => e
			display "Couldn't run rake"
			display e.message
		end

		def console
			app = extract_app
			cmd = args.join(' ').strip
			if cmd.empty?
				console_session(app)
			else
				display heroku.console(app, cmd)
			end
		rescue Heroku::Client::AppCrashed => e
			display "Couldn't run console command"
			display e.message
		end

		def console_session(app)
			heroku.console(app) do |console|
				console_history_read(app)

				display "Ruby console for #{app}.#{heroku.host}"
				while cmd = Readline.readline('>> ')
					unless cmd.nil? || cmd.strip.empty?
						console_history_add(app, cmd)
						break if cmd.downcase.strip == 'exit'
						display console.run(cmd)
					end
				end
			end
		end

		def restart
			app_name = extract_app
			heroku.restart(app_name)
			display "Servers restarted"
		end

		def destroy
			if name = extract_option('--app')
				info = heroku.info(name)
				url  = info[:domain_name] || "http://#{info[:name]}.#{heroku.host}/"
				conf = nil

				display("Permanently destroy #{url} (y/n)? ", false)
				if ask.downcase == 'y'
					heroku.destroy(name)
					if remotes = git_remotes(Dir.pwd)
						remotes.each do |remote_name, remote_app|
							next if name != remote_app
							shell "git remote rm #{remote_name}"
						end
					end
					display "Destroyed #{name}"
				end
			else
				display "Set the app you want to destroy adding --app <app name> to this command"
			end
		end

		protected
			@@kb = 1024
			@@mb = 1024 * @@kb
			@@gb = 1024 * @@mb
			def format_bytes(amount)
				amount = amount.to_i
				return '(empty)' if amount == 0
				return amount if amount < @@kb
				return "#{(amount / @@kb).round}k" if amount < @@mb
				return "#{(amount / @@mb).round}M" if amount < @@gb
				return "#{(amount / @@gb).round}G"
			end

			def console_history_dir
				FileUtils.mkdir_p(path = "#{home_directory}/.heroku/console_history")
				path
			end

			def console_history_file(app)
				"#{console_history_dir}/#{app}"
			end

			def console_history_read(app)
				history = File.read(console_history_file(app)).split("\n")
				if history.size > 50
					history = history[0,50]
					File.open(console_history_file(app), "w") { |f| f.puts history.join("\n") }
				end
				history.each { |cmd| Readline::HISTORY.push(cmd) }
			rescue Errno::ENOENT
			end

			def console_history_add(app, cmd)
				Readline::HISTORY.push(cmd)
				File.open(console_history_file(app), "a") { |f| f.puts cmd + "\n" }
			end

	end
end
