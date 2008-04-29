# This wraps the Heroku::Client class with higher-level actions suitable for
# use from the command line.
class Heroku::CommandLine
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

		write_generic_database_yml(name)

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

	############

	def heroku    # :nodoc:
		@heroku ||= init_heroku
	end

	def init_heroku    # :nodoc:
		Heroku::Client.new(user, password, ENV['HEROKU_HOST'] || 'heroku.com')
	end

	def user    # :nodoc:
		@credentials ||= get_credentials
		@credentials[0]
	end

	def password    # :nodoc:
		@credentials ||= get_credentials
		@credentials[1]
	end

	def credentials_file
		"#{ENV['HOME']}/.heroku/credentials"
	end

	def get_credentials    # :nodoc:
		if File.exists? credentials_file
			File.read(credentials_file).split("\n")
		else
			user, password = ask_for_credentials
			save_credentials user, password
			[ user, password ]
		end
	end

	def echo_off
		system "stty -echo"
	end

	def echo_on
		system "stty echo"
	end

	def ask_for_credentials
		puts "Enter your Heroku credentials."

		print "Email: "
		user = gets.strip

		print "Password: "
		echo_off
		password = gets.strip
		puts
		echo_on

		[ user, password ]
	end

	def save_credentials(user, password)
		write_credentials(user, password)
		begin
			upload_authkey
		rescue Heroku::Client::Unauthorized
			delete_credentials
			raise
		end
	end

	def write_credentials(user, password)
		FileUtils.mkdir_p(File.dirname(credentials_file))
		File.open(credentials_file, 'w') do |f|
			f.puts user
			f.puts password
		end
	end

	def delete_credentials
		FileUtils.rm_f(credentials_file)
	end

	def upload_authkey(*args)
		display "Uploading ssh public key"
		heroku.upload_authkey(authkey)
	end

	def authkey_type(key_type)
		filename = "#{ENV['HOME']}/.ssh/id_#{key_type}.pub"
		File.exists?(filename) ? File.read(filename) : nil
	end

	def authkey
		%w( rsa dsa ).each do |key_type|
			key = authkey_type(key_type)
			return key if key
		end
		raise "Your ssh public key was not found. Make sure you have a rsa or dsa key in #{ENV['HOME']}/.ssh"
	end

	def write_generic_database_yml(rails_dir)
		File.open("#{rails_dir}/config/database.yml", "w") do |f|
			f.write <<EOYAML
development:
  adapter: sqlite3
  database: db/development.sqlite3

test:
  adapter: sqlite3
  database: db/test.sqlite3
EOYAML
		end
	end

	def display(msg)
		puts msg
	end
end
