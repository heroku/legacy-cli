require 'fileutils'

module Heroku::Command
	class Base
		attr_accessor :args
		def initialize(args)
			@args = args
		end

		def display(msg, newline=true)
			newline ? puts(msg) : print(msg)
		end

		def ask
			gets.strip
		end

		def shell(cmd)
			`#{cmd}`
		end

		def heroku
			@heroku ||= Heroku::Command.run_internal('auth:client', args)
		end

		def extract_app
			extract_option('--app') ||
			extract_app_in_dir(Dir.pwd) ||
			raise(CommandFailed, "No app specified.\nRun this command from app folder or set it adding --app <app name>")
		end

		def extract_app_in_dir(dir)
			git_config = "#{dir}/.git/config"
			unless File.exists?(git_config)
				parent = dir.split('/')[0..-2].join('/')
				return extract_app_in_dir(parent) unless parent.empty?
			else
				remotes = File.read(git_config).split(/\n/).map do |remote|
					(remote.match(/url = git@#{heroku.host}:([\w\d-]+)\.git/) || [])[1]
				end.compact
				case remotes.size
					when 0; return nil
					when 1; return remotes.first
					else
						current_dir_name = dir.split('/').last.downcase
						remotes.select { |r| r.downcase == current_dir_name }.first
				end
			end
		end

		def extract_option(options, default=true)
			values = options.is_a?(Array) ? options : [options]
			return unless opt_index = args.select { |a| values.include? a }.first
			if args.size > args.index(opt_index) && opt_value = args[args.index(opt_index) + 1]
				if opt_value.include?('--')
					opt_value = nil
				else
					args.delete(opt_value)
				end
			end
			opt_value ||= default
			args.delete(opt_index)
			block_given? ? yield(opt_value) : opt_value
		end

		def web_url(name)
			"http://#{name}.#{heroku.host}/"
		end

		def git_url(name)
			"git@#{heroku.host}:#{name}.git"
		end

		def app_urls(name)
			"#{web_url(name)} | #{git_url(name)}"
		end

		def home_directory
			running_on_windows? ? ENV['USERPROFILE'] : ENV['HOME']
		end

		def running_on_windows?
			RUBY_PLATFORM =~ /mswin32/
		end
	end

	class BaseWithApp < Base
		def app
			@app ||= extract_app
		end
	end
end
