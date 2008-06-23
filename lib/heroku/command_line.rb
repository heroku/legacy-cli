# This wraps the Heroku::Client class with higher-level actions suitable for
# use from the command line.
class Heroku::CommandLine
	class CommandFailed < RuntimeError; end

	def execute(command, args)
		extract_key!
		send(command, args)
	rescue RestClient::Unauthorized
		display "Authentication failure"
	rescue RestClient::RequestFailed => e
		msg = e.message.strip rescue ''
		msg = 'Internal server error' if msg == ''
		display msg
	rescue Heroku::CommandLine::CommandFailed => e
		display e.message
	end

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

		raise CommandFailed, "git clone failed" unless system("git clone git@#{heroku.host}:#{name}.git")

		cur_dir = "#{Dir.pwd}/#{name}"
		%w( log db tmp public public/stylesheets ).each do |dir|
			Dir.mkdir("#{cur_dir}/#{dir}") unless File.directory?("#{cur_dir}/#{dir}")
		end

		write_generic_database_yml(name)

		command_separator = running_on_windows? ? '&&' : ';'
		system "cd #{name}#{command_separator}rake db:migrate"
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
	attr_accessor :credentials

	def heroku    # :nodoc:
		@heroku ||= init_heroku
	end

	def init_heroku    # :nodoc:
		Heroku::Client.new(user, password, ENV['HEROKU_HOST'] || 'heroku.com')
	end

	def user    # :nodoc:
		get_credentials
		@credentials[0]
	end

	def password    # :nodoc:
		get_credentials
		@credentials[1]
	end

	def credentials_file
		"#{home_directory}/.heroku/credentials"
	end

	def get_credentials    # :nodoc:
		return if @credentials
		unless @credentials = read_credentials
			@credentials = ask_for_credentials
			save_credentials
		end
		@credentials
	end

	def read_credentials
		if File.exists? credentials_file
			return File.read(credentials_file).split("\n")
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
		password = running_on_windows? ? ask_for_password_on_windows : ask_for_password

		[ user, password ]
	end

	def ask_for_password_on_windows
		require "Win32API"
		char = nil
		password = ''

		while char = Win32API.new("crtdll", "_getch", [ ], "L").Call do
			break if char == 10 || char == 13 # received carriage return or newline
			if char == 127 || char == 8 # backspace and delete
				password.slice!(-1, 1)
			else
				password << char.chr
			end
		end
		puts
		return password
	end

	def ask_for_password
		echo_off
		password = gets.strip
		puts
		echo_on
		return password
	end

	def save_credentials
		begin
			write_credentials
			upload_authkey
		rescue RestClient::Unauthorized => e
			delete_credentials
			raise e unless retry_login?

			display "\nAuthentication failed"
			@credentials = ask_for_credentials
			@heroku = init_heroku
			retry
		rescue Exception => e
			delete_credentials
			raise e
		end
	end

	def retry_login?
		@login_attempts ||= 0
		@login_attempts += 1
		@login_attempts < 3
	end

	def write_credentials
		FileUtils.mkdir_p(File.dirname(credentials_file))
		File.open(credentials_file, 'w') do |f|
			f.puts self.credentials
		end
		set_credentials_permissions
	end

	def set_credentials_permissions
		FileUtils.chmod 0700, File.dirname(credentials_file)
		FileUtils.chmod 0600, credentials_file
	end

	def delete_credentials
		FileUtils.rm_f(credentials_file)
	end

	def extract_key!
		return unless key_index = ARGV.select { |a| %w( -k --key ).include? a }.first
		key_path = ARGV[ARGV.index(key_index) + 1] rescue ''

		# remove key from ARGV so it doesnt' get read by gets
		ARGV.delete(key_index)
		ARGV.delete(key_path)
		raise "Please inform the full path for your ssh public key" if File.directory?(key_path)
		raise "Could not read ssh public key in #{key_path}" unless @ssh_key = authkey_read(key_path)
	end

	def upload_authkey(*args)
		display "Uploading ssh public key"
		heroku.upload_authkey(authkey)
	end

	def authkey_type(key_type)
		authkey_read("#{home_directory}/.ssh/id_#{key_type}.pub")
	end

	def authkey_read(filename)
		File.read(filename) if File.exists?(filename)
	end

	def authkey
		return @ssh_key if @ssh_key
		%w( rsa dsa ).each do |key_type|
			key = authkey_type(key_type)
			return key if key
		end
		raise "Your ssh public key was not found. Make sure you have a rsa or dsa key in #{home_directory}/.ssh"
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

	def home_directory
		running_on_windows? ? ENV['USERPROFILE'] : ENV['HOME']
	end

	def running_on_windows?
		RUBY_PLATFORM =~ /mswin32/
	end
end
