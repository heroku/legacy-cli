class Wrapper
	def list(args)
		list = heroku.list
		if list.size > 0
			puts "=== My Apps"
			puts list.join("\n")
		else
			puts "You have no apps."
		end
	end

	def create(args)
		name = args.shift.downcase.strip rescue nil
		name = heroku.create(name)
		puts "Created http://#{name}.#{heroku.host}/"
	end

	def destroy(args)
		name = args.shift.strip.downcase rescue ""
		if name.length == 0
			puts "Usage: app destroy [appname]"
		end
		heroku.destroy(name)
		puts "Destroyed #{name}"
	end

	def import(args)
		name = args.shift.downcase.strip rescue nil

		dir = Dir.pwd
		raise "Current dir doesn't look like a Rails app" unless File.directory? "#{dir}/config" and File.directory? "#{dir}/app"

		if File.exists? "#{dir}/config/heroku.yml"
			raise "This is already an existing app, use \"app push\" to push your changes."
		end

		puts "Archiving current directory for upload"
		tgz = archive(dir)

		puts "Creating new app"
		name = heroku.create(name)

		puts "Uploading #{(tgz.size/1024).round}kb archive"
		heroku.import(name, tgz)

		puts "Imported to http://#{name}.#{heroku.host}/"
		write_app_config(dir, name)
	end

	def export(args)
		name = args.shift.strip.downcase rescue ""
		if name.length == 0
			puts "Usage: app export [appname]"
		end

		tgz = heroku.export(name)
		unarchive(tgz, name)

		write_app_config(name, name)

		puts "#{name} exported."
	end

	def push(args)
		dir = Dir.pwd
		config = app_config(dir) rescue raise("This dir is not an existing app, try import")

		name = config[:name]

		tgz = archive(dir)
		puts "Uploading #{(tgz.size/1024).round}kb archive to #{name}"
		heroku.import(name, tgz)
	end

	############

	def heroku
		@heroku ||= init_heroku
	end

	def init_heroku
		HerokuLink.new(ENV['HEROKU_HOST'] || 'heroku.com', user, password)
	end

	def write_app_config(dir, name)
		File.open("#{dir}/config/heroku.yml", "w") do |f|
			f.write YAML.dump(:name => name)
		end
	end

	def app_config(dir)
		YAML.load(File.read("#{dir}/config/heroku.yml"))
	end

	def user
		@credentials ||= get_credentials
		@credentials[0]
	end

	def password
		@credentials ||= get_credentials
		@credentials[1]
	end

	def credentials_file
		"#{ENV['HOME']}/.heroku/credentials"
	end

	def get_credentials
		if File.exists? credentials_file
			File.read(credentials_file).split("\n")
		else
			ask_for_credentials
		end
	end

	def echo_off
		system "stty -echo"
	end

	def echo_on
		system "stty echo"
	end

	def ask_for_credentials
		print "User: "
		user = gets.strip

		print "Password: "
		echo_off
		password = gets.strip
		puts
		echo_on

		save_credentials user, password

		[ user, password ]
	end

	def save_credentials(user, password)
		FileUtils.mkdir_p(File.dirname(credentials_file))
		File.open(credentials_file, 'w') do |f|
			f.puts user
			f.puts password
		end
	end

	def archive(dir)
		`cd #{dir}; tar cz *`
	end

	def unarchive(tgz, name)
		Dir.mkdir(name)

		begin
			IO.popen("cd #{name}; tar xz", "w") do |pipe|
				pipe.write tgz
			end
			first_entry = Dir.open(name).detect { |f| f.slice(0, 1) != '.' }
			raise "couldn't find first entry" unless first_entry and first_entry.length > 0
			system "cd #{name}; mv #{first_entry}/* .; rmdir #{first_entry}"
		rescue
			system "rm -rf #{name}"
			raise
		end
	end
end
