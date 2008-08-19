# This wraps the Heroku::Client class with higher-level actions suitable for
# use from the command line.

require 'fileutils'

class Heroku::CommandLine
	class CommandFailed < RuntimeError; end

	def execute(command, args)
		extract_key!
		send(command, args)
	rescue RestClient::Unauthorized
		display "Authentication failure"
	rescue RestClient::RequestFailed => e
		display extract_error(e.response)
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

	def show(args)
		name = args.shift.downcase.strip rescue nil
		attrs = heroku.show(name)
		display "=== #{attrs[:name]}"
		display "Web URL:        http://#{attrs[:name]}.#{heroku.host}/"
		display "Domain name:    http://#{attrs[:domain_name]}/" if attrs[:domain_name]
		display "Git Repo:       git@#{heroku.host}:#{attrs[:name]}.git"
		display "Mode:           #{ attrs[:production] == 'true' ? 'production' : 'development' }"
		display "Public:         #{ attrs[:'share-public'] == 'true' ? 'true' : 'false' }"

		first = true
		lead = "Collaborators:"
		attrs[:collaborators].each do |collaborator|
			display "#{first ? lead : ' ' * lead.length}  #{collaborator[:email]} (#{collaborator[:access]})"
			first = false
		end
	end

	def create(args)
		options = {}
		extract_option(args, '--origin') do |url|
			options[:origin] = url
		end
		name = args.shift.downcase.strip rescue nil
		name = heroku.create(name, options)
		display "Created http://#{name}.#{heroku.host}/ | git@#{heroku.host}:#{name}.git"
	end

	def update(args)
		name = args.shift.downcase.strip rescue nil
		raise CommandFailed, "Invalid app name" unless name

		attributes = {}
		extract_option(args, '--name') do |new_name|
			attributes[:name] = new_name
		end
		extract_option(args, '--public', %w( true false )) do |public|
			attributes[:share_public] = (public == 'true')
		end
		extract_option(args, '--mode', %w( production development )) do |mode|
			attributes[:production] = (mode == 'production')
		end
		extract_option(args, '--domain-name') do |domain_name|
			domain_name = '' if domain_name == 'nil'
			attributes[:domain_name] = domain_name
		end
		raise CommandFailed, "Nothing to update" if attributes.empty?
		heroku.update(name, attributes)

		app_name = attributes[:name] || name
		display "http://#{app_name}.#{heroku.host}/ updated"
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

	def collaborators(args)
		name = args.shift.strip.downcase rescue ""
		if name.length == 0
			display "Usage: heroku collaborators <app>"
		else
			access = extract_option(args, '--access', %w( edit view )) || 'view'
			extract_option(args, '--add') do |email|
				return add_collaborator(name, email, access)
			end
			extract_option(args, '--update') do |email|
				return update_collaborator(name, email, access)
			end
			extract_option(args, '--remove') do |email|
				return remove_collaborator(name, email)
			end
			return list_collaborators(name)
		end
	end

	def add_collaborator(name, email, access)
		display heroku.add_collaborator(name, email, access)
	end

	def update_collaborator(name, email, access)
		heroku.update_collaborator(name, email, access)
		display "Collaborator updated"
	end

	def remove_collaborator(name, email)
		heroku.remove_collaborator(name, email)
		display "Collaborator removed"
	end

	def list_collaborators(name)
		list = heroku.list_collaborators(name)
		display list.map { |c| "#{c[:email]} (#{c[:access]})" }.join("\n")
	end

	def db_import(args)
		app_name = args.shift.strip.downcase rescue ""
		if app_name.length == 0
			display "Usage: heroku db:import <app>"
		else
			raise(CommandFailed, "db/data.yml does not exist.  Install the yaml_db plugin (git://github.com/adamwiggins/yaml_db.git) and run rake db:dump to create it.") unless File.exists?('db/data.yml')
			heroku.db_import(app_name, 'db/data.yml')
		end
	end

	def db_export(args)
		app_name = args.shift.strip.downcase rescue ""
		if app_name.length == 0
			display "Usage: heroku db:export <app>"
		else
			fname = File.directory?('db') ? 'db/data.yml' : 'data.yml'
			heroku.db_export(app_name, fname)
			puts "#{File.stat(fname).size} byte database dumped to #{fname}"
		end
	end

	def rake(args)
		app_name = args.shift.strip.downcase rescue ""
		cmd = args.join(' ')
		if app_name.length == 0 or cmd.length == 0
			display "Usage: heroku rake <app> <command>"
		else
			puts heroku.rake(app_name, cmd)
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
		return unless key_path = extract_option(ARGV, ['-k', '--key'])
		raise "Please inform the full path for your ssh public key" if File.directory?(key_path)
		raise "Could not read ssh public key in #{key_path}" unless @ssh_key = authkey_read(key_path)
	end

	def extract_option(args, options, valid_values=nil)
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

	def extract_error(response)
		return "Not found" if response.code.to_i == 404

		msg = parse_error_xml(response.body) rescue ''
		msg = 'Internal server error' if msg.empty?
		msg
	end

	def parse_error_xml(body)
		xml_errors = REXML::Document.new(body).elements.to_a("//errors/error")
		xml_errors.map { |a| a.text }.join(" / ")
	end

	def running_on_windows?
		RUBY_PLATFORM =~ /mswin32/
	end
end
