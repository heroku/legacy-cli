require 'fileutils'
require 'readline'

# This wraps the Heroku::Client class with higher-level actions suitable for
# use from the command line.
class Heroku::CommandLine
	class CommandFailed < RuntimeError; end

	def execute(command, args)
		send(command, args)
	rescue RestClient::Unauthorized
		display "Authentication failure"
	rescue RestClient::ResourceNotFound
		display "Resource not found.  (Did you mistype the app name?)"
	rescue RestClient::RequestFailed => e
		display extract_error(e.response)
	rescue Heroku::CommandLine::CommandFailed => e
		display e.message
	end

	def list(args)
		list = heroku.list
		if list.size > 0
			display list.join("\n")
		else
			display "You have no apps."
		end
	end

	def info(args)
		name = args.shift.downcase.strip rescue ""
		if name.length == 0 or name.slice(0, 1) == '-'
			display "Usage: heroku info <app>"
		else
			attrs = heroku.info(name)
			display "=== #{attrs[:name]}"
			display "Web URL:        http://#{attrs[:name]}.#{heroku.host}/"
			display "Domain name:    http://#{attrs[:domain_name]}/" if attrs[:domain_name]
			display "Git Repo:       git@#{heroku.host}:#{attrs[:name]}.git"
			display "Mode:           #{ attrs[:production] == 'true' ? 'production' : 'development' }"
			display "Code size:      #{format_bytes(attrs[:code_size])}" if attrs[:code_size]
			display "Data size:      #{format_bytes(attrs[:data_size])}" if attrs[:data_size]
			display "Public:         #{ attrs[:'share-public'] == 'true' ? 'true' : 'false' }"

			first = true
			lead = "Collaborators:"
			attrs[:collaborators].each do |collaborator|
				display "#{first ? lead : ' ' * lead.length}  #{collaborator[:email]} (#{collaborator[:access]})"
				first = false
			end
		end
	end

	def create(args)
		name = args.shift.downcase.strip rescue nil
		name = heroku.create(name, {})
		display "Created http://#{name}.#{heroku.host}/ | git@#{heroku.host}:#{name}.git"
	end

	def update(args)
		name = args.shift.downcase.strip rescue ""
		raise CommandFailed, "Invalid app name" if name.length == 0 or name.slice(0, 1) == '-'

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
		raise CommandFailed, "Nothing to update" if attributes.empty?
		heroku.update(name, attributes)

		app_name = attributes[:name] || name
		display "http://#{app_name}.#{heroku.host}/ updated"
	end

	def clone(args)
		name = args.shift.downcase.strip rescue ""
		if name.length == 0 or name.slice(0, 1) == '-'
			display "Usage: heroku clone <app>"
			display "(this command is deprecated in favor of using the git repo url directly)"
		else
			cmd = "git clone #{git_repo_for(name)}"
			display cmd
			system cmd
		end
	end

	def destroy(args)
		name = args.shift.strip.downcase rescue ""
		if name.length == 0 or name.slice(0, 1) == '-'
			display "Usage: heroku destroy <app>"
		else
			heroku.destroy(name)
			display "Destroyed #{name}"
		end
	end

	def sharing(args)
		name = args.shift.strip.downcase rescue ""
		if name.length == 0 or name.slice(0, 1) == '-'
			display "Usage: heroku sharing <app>"
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

	def collaborators(args)
		sharing(args)
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

	def domains(args)
		app = args.shift.strip.downcase rescue ""
		if app.length == 0 or app.slice(0, 1) == '-'
			display "Usage: heroku domains <app>"
		else
			extract_option(args, '--add') do |domain|
				return display('Usage: heroku domains <app> --add <domain>') unless domain
				return add_domain(app, domain)
			end
			extract_option(args, '--remove') do |domain|
				return display('Usage: heroku domains <app> --remove <domain>') unless domain
				return remove_domain(app, domain)
			end
			extract_option(args, '--remove-all') do
				return remove_domains(app)
			end
			return list_domains(app)
		end
	end

	def add_domain(app, domain)
		heroku.add_domain(app, domain)
		display "Added #{domain} as a custom domain name to #{app}.#{heroku.host}"
	end

	def remove_domain(app, domain)
		heroku.remove_domain(app, domain)
		display "Removed #{domain} as a custom domain name to #{app}.#{heroku.host}"
	end

	def remove_domains(app)
		heroku.remove_domains(app)
		display "Removed all domain names for #{app}.#{heroku.host}"
	end

	def list_domains(app)
		display "Domain names for #{app}.#{heroku.host}:"
		display heroku.list_domains(app).join("\n")
	end

	def git_repo_for(name)
		"git@#{heroku.host}:#{name}.git"
	end

	def rake(args)
		app_name = args.shift.strip.downcase rescue ""
		cmd = args.join(' ')
		if app_name.length == 0 or cmd.length == 0
			display "Usage: heroku rake <app> <command>"
		else
			display heroku.rake(app_name, cmd)
		end
	end

	def console(args)
		app_name = args.shift.strip.downcase rescue ""
		cmd = args.join(' ').strip
		if app_name.length == 0
			display "Usage: heroku console <app>"
		else
			if cmd.empty?
				console_session(app_name)
			else
				display heroku.console(app_name, cmd)
			end
		end
	end

	def console_session(app)
		display "Ruby console for #{app}.#{heroku.host}"
		heroku.console(app) do |console|
			while cmd = Readline.readline('>> ')
				break if cmd.downcase.strip == 'exit'
				unless cmd.nil? || cmd.strip.empty?
					Readline::HISTORY.push(cmd)
					display console.run(cmd)
				end
			end
		end
	end

	def restart(args)
		app_name = args.shift.strip.downcase rescue ""
		if app_name.length == 0
			display "Usage: heroku restart <app>"
		else
			heroku.restart(app_name)
			display "Servers restarted"
		end
	end

	def logs(args)
		app_name = args.shift.strip.downcase rescue ""
		if app_name.length == 0
			display "Usage: heroku logs <app>"
		else
			display heroku.logs(app_name)
		end
	end

	def bundle_capture(args)
		app_name = args.shift.strip.downcase rescue ""
		if app_name.length == 0
			display "Usage: heroku bundle:capture <app> [<bundle>]"
		else
			bundle = args.shift.strip.downcase rescue nil

			bundle = heroku.bundle_capture(app_name, bundle)
			display "Began capturing bundle #{bundle} from #{app_name}"
		end
	end

	def bundle_download(args)
		app_name = args.shift.strip.downcase rescue ""
		if app_name.length == 0
			display "Usage: heroku bundle:download <app> [<bundle>]"
		else
			fname = "#{app_name}.tar.gz"
			bundle = args.shift.strip.downcase rescue nil
			heroku.bundle_download(app_name, fname, bundle)
			display "Downloaded #{File.stat(fname).size} byte bundle #{fname}"
		end
	end

	def bundle_animate(args)
		app_name = args.shift.strip.downcase rescue ""
		bundle = args.shift.strip.downcase rescue ""
		if app_name.length == 0 or bundle.length == 0
			display "Usage: heroku bundle:animate <app> <bundle>"
		else
			name = heroku.create(nil, :origin_bundle_app => app_name, :origin_bundle => bundle)
			display "Animated #{app_name} #{bundle} into http://#{name}.#{heroku.host}/ | git@#{heroku.host}:#{name}.git"
		end
	end

	def bundle_list(args)
		app_name = args.shift.strip.downcase rescue ""
		if app_name.length == 0
			display "Usage: heroku bundle:list <app>"
		else
			list = heroku.bundles(app_name)
			if list.size > 0
				list.each do |bundle|
					status = bundle[:completed] ? 'completed' : 'capturing'
					display "#{bundle[:name]}\t\t#{status} | #{bundle[:created_at].strftime("%m/%d/%Y %H:%M")}"
				end
			else
				display "#{app_name} has no bundles."
			end
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
			add_key
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

	def keys(*args)
		args = args.first  # something weird with ruby argument passing

		if args.empty? || args == ['--long']
			list_keys(args.first)
			return
		end

		extract_option(args, '--add') do |keyfile|
			add_key(keyfile)
			return
		end
		extract_option(args, '--remove') do |arg|
			remove_key(arg)
			return
		end

		display "Usage: heroku keys [--add or --remove]"
	end

	def list_keys(long=false)
		keys = heroku.keys
		if keys.empty?
			display "No keys for #{user}"
		else
			display "=== #{keys.size} key#{keys.size > 1 ? 's' : ''} for #{user}"
			keys.each do |key|
				display long ? key.strip : format_key_for_display(key)
			end
		end
	end

	def add_key(keyfile=nil)
		keyfile ||= find_key
		key = File.read(keyfile)

		display "Uploading ssh public key #{keyfile}"
		heroku.add_key(key)
	end

	def remove_key(arg)
		if arg == 'all'
			heroku.remove_all_keys
			display "All keys removed."
		else
			heroku.remove_key(arg)
			display "Key #{arg} removed."
		end
	end

	def find_key
		%w(rsa dsa).each do |key_type|
			keyfile = "#{home_directory}/.ssh/id_#{key_type}.pub"
			return keyfile if File.exists? keyfile
		end
		raise CommandFailed, "No ssh public key found in #{home_directory}/.ssh/id_[rd]sa.pub.  You may want to specify the full path to the keyfile."
	end

	# vvv Deprecated
	def upload_authkey(*args)
		extract_key!
		display "Uploading ssh public key"
		display "(upload_authkey is deprecated, please use \"heroku keys --add\" instead)"
		heroku.add_key(authkey)
	end

	def extract_key!
		return unless key_path = extract_option(ARGV, ['-k', '--key'])
		raise "Please inform the full path for your ssh public key" if File.directory?(key_path)
		raise "Could not read ssh public key in #{key_path}" unless @ssh_key = authkey_read(key_path)
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
		raise "Your ssh public key was not found.  Make sure you have a rsa or dsa key in #{home_directory}/.ssh, or specify the full path to the keyfile."
	end
	# ^^^ Deprecated

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

	# helpers - formatters
	def format_key_for_display(key)
		type, hex, local = key.strip.split(/\s/)
		[type, hex[0,10] + '...' + hex[-10,10], local].join(' ')
	end

	KB = 1024
	MB = 1024 * KB
	GB = 1024 * MB
	def format_bytes(amount)
		amount = amount.to_i
		return nil if amount == 0
		return amount if amount < KB
		return "#{(amount / KB).round}k" if amount < MB
		return "#{(amount / MB).round}M" if amount < GB
		return "#{(amount / GB).round}G"
	end
end
