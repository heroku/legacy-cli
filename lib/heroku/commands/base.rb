require 'fileutils'

module Heroku::Command
	class Base
		attr_accessor :args
		def initialize(args)
			@args = args
		end

		def display(msg)
			puts msg
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

		def extract_option(options, valid_values=nil)
			values = options.is_a?(Array) ? options : [options]
			return unless opt_index = args.select { |a| values.include? a }.first
			opt_value = args[args.index(opt_index) + 1] rescue nil

			# remove option from args
			args.delete(opt_index)
			args.delete(opt_value)

			if valid_values
				opt_value = opt_value.downcase if opt_value
				raise CommandFailed, "Invalid value '#{opt_value}' for option #{values.last}" unless valid_values.include?(opt_value)
			end

			block_given? ? yield(opt_value) : opt_value
		end

		def app_urls(name)
			"http://#{name}.#{heroku.host}/ | git@#{heroku.host}:#{name}.git"
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