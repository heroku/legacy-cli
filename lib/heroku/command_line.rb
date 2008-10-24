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
		name = extract_app(args)
		attrs = heroku.info(name)
		display "=== #{attrs[:name]}"
		display "Web URL:        http://#{attrs[:name]}.#{heroku.host}/"
		display "Domain name:    http://#{attrs[:domain_name]}/" if attrs[:domain_name]
		display "Git Repo:       git@#{heroku.host}:#{attrs[:name]}.git"
		display "Mode:           #{ attrs[:production] == 'true' ? 'production' : 'development' }"
		display "Code size:      #{format_bytes(attrs[:code_size])}" if attrs[:code_size]
		display "Data size:      #{format_bytes(attrs[:data_size])}" if attrs[:data_size]
		display "Public:         #{ attrs[:share_public] == 'true' ? 'true' : 'false' }"

		first = true
		lead = "Collaborators:"
		attrs[:collaborators].each do |collaborator|
			display "#{first ? lead : ' ' * lead.length}  #{collaborator[:email]} (#{collaborator[:access]})"
			first = false
		end
	end

	def create(args)
		name = args.shift.downcase.strip rescue nil
		name = heroku.create(name, {})
		display "Created http://#{name}.#{heroku.host}/ | git@#{heroku.host}:#{name}.git"
	end

	def update(args)
		name = extract_app(args)
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
		name = extract_app(args)
		cmd = "git clone #{git_repo_for(name)}"
		display cmd
		system cmd
	end

	def destroy(args)
		name = args.shift.downcase.strip rescue nil
		unless name
			display "Usage: heroku destroy <app>"
		else
			heroku.destroy(name)
			display "Destroyed #{name}"
		end
	end

	def sharing(args)
		name = extract_app(args)
		list = heroku.list_collaborators(name)
		display list.map { |c| "#{c[:email]} (#{c[:access]})" }.join("\n")
	end
	alias :collaborators :sharing
	alias :sharing_list  :sharing

	def sharing_add(args)
		name = extract_app(args)
		email = args.shift.downcase rescue nil
		access = extract_option(args, '--access', %w( edit view )) || 'view'
		display heroku.add_collaborator(name, email, access)
	end

	def sharing_remove(args)
		name = extract_app(args)
		email = args.shift.downcase rescue nil
		heroku.remove_collaborator(name, email)
		display "Collaborator removed"
	end

	def domains(args)
		name = extract_app(args)
		domains = heroku.list_domains(name)
		if domains.empty?
			display "No domain names for #{name}.#{heroku.host}"
		else
			display "Domain names for #{name}.#{heroku.host}:"
			display domains.join("\n")
		end
	end
	alias :domains_list :domains

	def domains_add(args)
		name = extract_app(args)
		domain = args.shift.downcase rescue nil
		heroku.add_domain(name, domain)
		display "Added #{domain} as a custom domain name to #{name}.#{heroku.host}"
	end

	def domains_remove(args)
		name = extract_app(args)
		domain = args.shift.downcase rescue nil
		heroku.remove_domain(name, domain)
		display "Removed #{domain} as a custom domain name to #{name}.#{heroku.host}"
	end

	def domains_clear(args)
		name = extract_app(args)
		heroku.remove_domains(name)
		display "Removed all domain names for #{name}.#{heroku.host}"
	end

	def git_repo_for(name)
		"git@#{heroku.host}:#{name}.git"
	end

	def rake(args)
		app_name = extract_app(args)
		cmd = args.join(' ')
		if cmd.length == 0
			display "Usage: heroku rake <command>"
		else
			display heroku.rake(app_name, cmd)
		end
	end

	def console(args)
		app_name = extract_app(args)
		cmd = args.join(' ').strip
		if cmd.empty?
			console_session(app_name)
		else
			display heroku.console(app_name, cmd)
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
		app_name = extract_app(args)
		heroku.restart(app_name)
		display "Servers restarted"
	end

	def logs(args)
		app_name = extract_app(args)
		display heroku.logs(app_name)
	end

	def bundle_capture(args)
		app_name = extract_app(args)
		bundle = args.shift.strip.downcase rescue nil

		bundle = heroku.bundle_capture(app_name, bundle)
		display "Began capturing bundle #{bundle} from #{app_name}"
	end

	def bundle_destroy(args)
		app_name = extract_app(args)
		bundle = args.first.strip.downcase rescue nil
		unless bundle
			display "Usage: heroku bundle:destroy <bundle>"
		else
			heroku.bundle_destroy(app_name, bundle)
			display "Destroyed bundle #{bundle} from #{app_name}"
		end
	end

	def bundle_download(args)
		app_name = extract_app(args)
		fname = "#{app_name}.tar.gz"
		bundle = args.shift.strip.downcase rescue nil
		heroku.bundle_download(app_name, fname, bundle)
		display "Downloaded #{File.stat(fname).size} byte bundle #{fname}"
	end

	def bundle_animate(args)
		app_name = extract_app(args)
		bundle = args.shift.strip.downcase rescue ""
		if bundle.length == 0
			display "Usage: heroku bundle:animate <bundle>"
		else
			name = heroku.create(nil, :origin_bundle_app => app_name, :origin_bundle => bundle)
			display "Animated #{app_name} #{bundle} into http://#{name}.#{heroku.host}/ | git@#{heroku.host}:#{name}.git"
		end
	end

	def bundle_list(args)
		app_name = extract_app(args)
		list = heroku.bundles(app_name)
		if list.size > 0
			list.each do |bundle|
				status = bundle[:completed] ? 'completed' : 'capturing'
				space  = ' ' * [(18 - bundle[:name].size),0].max
				display "#{bundle[:name]}" + space + "#{status} #{bundle[:created_at].strftime("%m/%d/%Y %H:%M")}"
			end
		else
			display "#{app_name} has no bundles."
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

	def extract_app(args)
		extract_option(args, '--app') ||
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
				remote.match(/url = git@#{heroku.host}:([\w\d-]+)\.git/)[1] rescue nil
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

	def keys(args)
		long = args.any? { |a| a == '--long' }
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
	alias :keys_list :keys

	def keys_add(args)
		keyfile = args.first || find_key
		key = File.read(keyfile)

		display "Uploading ssh public key #{keyfile}"
		heroku.add_key(key)
	end

	def keys_remove(arg)
		heroku.remove_key(arg)
		display "Key #{arg} removed."
	end

	def keys_clear(args)
		heroku.remove_all_keys
		display "All keys removed."
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
