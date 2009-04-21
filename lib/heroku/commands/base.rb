require 'fileutils'

module Heroku::Command
	class Base
		attr_accessor :args
		attr_reader :autodetected_app
		def initialize(args, heroku=nil)
			@args = args
			@heroku = heroku
			@autodetected_app = false
		end

		def display(msg, newline=true)
			if newline
				puts(msg)
			else
				print(msg)
				STDOUT.flush
			end
		end

		def error(msg)
			Heroku::Command.error(msg)
		end

		def ask
			gets.strip
		end

		def shell(cmd)
			`cd '#{Dir.pwd}' && #{cmd}`
		end

		def heroku
			@heroku ||= Heroku::Command.run_internal('auth:client', args)
		end

		def extract_app
			app = extract_option('--app')
			unless app
				app = extract_app_in_dir(Dir.pwd) ||
				raise(CommandFailed, "No app specified.\nRun this command from app folder or set it adding --app <app name>")
				@autodetected_app = true
			end
			app
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
			opt_position = args.index(opt_index) + 1
			if args.size > opt_position && opt_value = args[opt_position]
				if opt_value.include?('--')
					opt_value = nil
				else
					args.delete_at(opt_position)
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

		def escape(value)
			heroku.escape(value)
		end
	end

	class BaseWithApp < Base
		attr_accessor :app

		def initialize(args, heroku=nil)
			super(args, heroku)
			@app ||= extract_app
		end
	end
end
