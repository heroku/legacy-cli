# based on the Rails Plugin

module Heroku
	class Plugin
		attr_reader :name, :uri

		def self.directory
			home = ENV['USERPROFILE'] || ENV['HOME'] # TODO extract home_directory from Heroku::Command::Base
			"#{home}/.heroku/plugins"
		end

		def self.list
			Dir["#{directory}/*"].map do |folder|
				File.basename(folder)
			end
		end

		def self.load!
			list.each do |plugin|
				folder = "#{self.directory}/#{plugin}"
				$: << "#{folder}/lib"    if File.directory? "#{folder}/lib"
				load "#{folder}/init.rb" if File.exists?    "#{folder}/init.rb"
			end
		end

		def initialize(uri)
			@uri = uri
			guess_name(uri)
		end

		def to_s
			name
		end

		def install
			FileUtils.mkdir_p(install_path = "#{self.class.directory}/#{name}")
			Dir.chdir install_path do
				system("git init > /dev/null 2>&1")
				if system("git pull --depth 1 #{uri}  > /dev/null 2>&1")
					FileUtils.rm_rf %w(.git .gitignore)
				else
					FileUtils.rm_rf install_path
				end
			end
		end

		def uninstall
			path = "#{self.class.directory}/#{name}"
			FileUtils.rm_r path if File.directory?(path)
		end

		private 
			def guess_name(url)
				@name = File.basename(url)
				@name = File.basename(File.dirname(url)) if @name.empty?
				@name.gsub!(/\.git$/, '') if @name =~ /\.git$/
			end
	end
end
