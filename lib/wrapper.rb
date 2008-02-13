class Wrapper
	def list(args)
		list = heroku.list
		if list.size > 0
			display "=== My Apps"
			display list.join("\n")
		else
			display "You have no apps."
		end
	end

	def create(args)
		name = args.shift.downcase.strip rescue nil
		name = heroku.create(name)
		display "Created http://#{name}.#{heroku.host}/"
	end

	def clone(args)
		name = args.shift.downcase.strip rescue ""
		if name.length == 0
			display "Usage: heroku clone <app>"
		end

		return unless system "git clone git@#{heroku.host}:#{name}.git"

		return unless system "cd #{name}; mkdir -p log db tmp public/stylesheets"

		File.open("#{name}/config/database.yml", "w") do |f|
			f.write <<EOYAML
development:
  adapter: sqlite3
  database: db/development.sqlite3

test:
  adapter: sqlite3
  database: db/test.sqlite3
EOYAML
		end

		system "cd #{name}; rake db:migrate"
	end

	def destroy(args)
		name = args.shift.strip.downcase rescue ""
		if name.length == 0
			display "Usage: heroku destroy <app>"
		else
			heroku.destroy(name)
			display "Destroyed #{name}"
		end
	end

	def import(args)
		name = args.shift.downcase.strip rescue nil

		dir = Dir.pwd
		raise "Current dir doesn't look like a Rails app" unless File.directory? "#{dir}/config" and File.directory? "#{dir}/app"

		if File.exists? "#{dir}/config/heroku.yml"
			raise "This is already an existing app, use \"app push\" to push your changes."
		end

		display "Archiving current directory for upload"
		tgz = archive(dir)

		display "Creating new app"
		name = heroku.create(name)

		display "Uploading #{(tgz.size/1024).round}kb archive"
		heroku.import(name, tgz)

		display "Imported to http://#{name}.#{@heroku.host}/"
		write_app_config(dir, name)
	end

	def export(args)
		name = args.shift.strip.downcase rescue ""
		if name.length == 0
			display "Usage: heroku export <app>"
		else
			tgz = heroku.export(name)
			unarchive(tgz, name)

			write_app_config(name, name)

			display "#{name} exported."
		end
	end

	def push(args)
		system "git push"
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

		upload_authkey
	end

	def save_credentials(user, password)
		FileUtils.mkdir_p(File.dirname(credentials_file))
		File.open(credentials_file, 'w') do |f|
			f.puts user
			f.puts password
		end
	end

	def upload_authkey(*args)
		display "Uploading ssh public key"
		heroku.upload_authkey(authkey)
	end

	def authkey
		File.read("#{ENV['HOME']}/.ssh/id_rsa.pub")
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

	def display(msg)
		puts msg
	end
end
