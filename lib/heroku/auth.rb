require "cgi"
require "heroku"
require "heroku/client"
require "heroku/helpers"

require "netrc"

class Heroku::Auth
  class << self
    include Heroku::Helpers

    attr_accessor :credentials

    def api
      @api ||= begin
        debug "Using API with key: #{password[0,6]}..."
        api = Heroku::API.new(default_params.merge(:api_key => password))

        def api.request(params, &block)
          response = super
          if response.headers.has_key?('X-Heroku-Warning')
            Heroku::Command.warnings.concat(response.headers['X-Heroku-Warning'].split("\n"))
          end
          response
        end

        api
      end
    end

    def client
      @client ||= begin
        client = Heroku::Client.new(user, password, host)
        client.on_warning { |msg| self.display("\n#{msg}\n\n") }
        client
      end
    end

    def login
      delete_credentials
      get_credentials
    end

    def logout
      delete_credentials
    end

    # just a stub; will raise if not authenticated
    def check
      api.get_user
    end

    def default_host
      "heroku.com"
    end

    def http_git_host
      ENV['HEROKU_HTTP_GIT_HOST'] || "git.#{host}"
    end

    def git_host
      ENV['HEROKU_GIT_HOST'] || host
    end

    def host
      ENV['HEROKU_HOST'] || default_host
    end

    def subdomains
      %w(api git)
    end

    def reauthorize
      @credentials = ask_for_and_save_credentials
    end

    def user    # :nodoc:
      get_credentials[0]
    end

    def password    # :nodoc:
      get_credentials[1]
    end

    def api_key(user=get_credentials[0], password=get_credentials[1])
      @api ||= Heroku::API.new(default_params)
      api_key = @api.post_login(user, password).body["api_key"]
      @api = nil
      api_key
    rescue Heroku::API::Errors::Forbidden => e
      if e.response.headers.has_key?("Heroku-Two-Factor-Required")
        ask_for_second_factor
        retry
      end
    rescue Heroku::API::Errors::Unauthorized => e
      id = json_decode(e.response.body)["id"]
      raise if id != "invalid_two_factor_code"
      delete_credentials
      display "Authentication failed due to an invalid two-factor code."
      display "Please check your code was typed correctly and that your"
      display "authenticator's time keeping is accurate."
      exit 1
    end

    def get_credentials    # :nodoc:
      @credentials ||= (read_credentials || ask_for_and_save_credentials)
    end

    def delete_credentials
      if File.exists?(legacy_credentials_path)
        FileUtils.rm_f(legacy_credentials_path)
      end
      if netrc
        subdomains.each do |sub|
          netrc.delete("#{sub}.#{host}")
        end
        netrc.save
      end
      @api, @client, @credentials = nil, nil
    end

    def legacy_credentials_path
      if host == default_host
        "#{home_directory}/.heroku/credentials"
      else
        "#{home_directory}/.heroku/credentials.#{CGI.escape(host)}"
      end
    end

    def netrc_path
      default = Netrc.default_path
      encrypted = default + ".gpg"
      if File.exists?(encrypted)
        encrypted
      else
        default
      end
    end

    def netrc   # :nodoc:
      @netrc ||= begin
        File.exists?(netrc_path) && Netrc.read(netrc_path)
      rescue => error
        case error.message
        when /^Permission bits for/
          abort("#{error.message}.\nYou should run `chmod 0600 #{netrc_path}` so that your credentials are NOT accessible by others.")
        when /EACCES/
          error("Error reading #{netrc_path}\n#{error.message}\nMake sure this user can read/write this file.")
        else
          error("Error reading #{netrc_path}\n#{error.message}\nYou may need to delete this file and run `heroku login` to recreate it.")
        end
      end
    end

    def read_credentials
      if ENV['HEROKU_API_KEY']
        ['', ENV['HEROKU_API_KEY']]
      else
        # convert legacy credentials to netrc
        if File.exists?(legacy_credentials_path)
          @api, @client = nil
          @credentials = File.read(legacy_credentials_path).split("\n")
          write_credentials
          FileUtils.rm_f(legacy_credentials_path)
        end

        # read netrc credentials if they exist
        if netrc
          # force migration of long api tokens (80 chars) to short ones (40)
          # #write_credentials rewrites both api.* and code.*
          credentials = netrc["api.#{host}"]
          if credentials && credentials[1].length > 40
            @credentials = [ credentials[0], credentials[1][0,40] ]
            write_credentials
          end

          netrc["api.#{host}"]
        end
      end
    end

    def write_credentials
      FileUtils.mkdir_p(File.dirname(netrc_path))
      FileUtils.touch(netrc_path)
      unless running_on_windows?
        FileUtils.chmod(0600, netrc_path)
      end
      subdomains.each do |sub|
        netrc["#{sub}.#{host}"] = self.credentials
      end
      netrc.save
    end

    def echo_off
      with_tty do
        system "stty -echo"
      end
    end

    def echo_on
      with_tty do
        system "stty echo"
      end
    end

    def ask_for_credentials
      puts "Enter your Heroku credentials."

      print "Email: "
      user = ask

      print "Password (typing will be hidden): "
      password = running_on_windows? ? ask_for_password_on_windows : ask_for_password
      HTTPInstrumentor.filter_parameter(password)

      [user, api_key(user, password)]
    end

    def ask_for_second_factor
      $stderr.print "Two-factor code: "
      api.second_factor = ask
    end

    def preauth
      if Heroku.app_name
        second_factor = ask_for_second_factor
        api.request(:method => :put,
                    :path => "/apps/#{Heroku.app_name}/pre-authorizations",
                    :headers => {"Heroku-Two-Factor-Code" => second_factor})
      end
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
          # windows might throw a -1 at us so make sure to handle RangeError
          (password << char.chr) rescue RangeError
        end
      end
      puts
      return password
    end

    def ask_for_password
      begin
        echo_off
        password = ask
        puts
      ensure
        echo_on
      end
      return password
    end

    def ask_for_and_save_credentials
      warn "WARNING: heroku-accounts plugin is installed. This plugin is known to have problems with HTTP Git." if defined?(Heroku::Command::Accounts)
      @credentials = ask_for_credentials
      debug "Logged in as #{@credentials[0]} with key: #{@credentials[1][0,6]}..."
      write_credentials
      check
      @credentials
    rescue Heroku::API::Errors::NotFound, Heroku::API::Errors::Unauthorized => e
      delete_credentials
      display "Authentication failed."
      warn "WARNING: HEROKU_API_KEY is set to an invalid key." if ENV['HEROKU_API_KEY']
      retry if retry_login?
      exit 1
    rescue => e
      delete_credentials
      raise e
    end

    def associate_or_generate_ssh_key
      unless File.exists?("#{home_directory}/.ssh/id_rsa.pub")
        display "Could not find an existing public key at ~/.ssh/id_rsa.pub"
        display "Would you like to generate one? [Yn] ", false
        unless ask.strip.downcase =~ /^n/
          display "Generating new SSH public key."
          generate_ssh_key("#{home_directory}/.ssh/id_rsa")
          associate_key("#{home_directory}/.ssh/id_rsa.pub")
          return
        end
      end

      chosen = ssh_prompt
      associate_key(chosen) if chosen
    end

    def ssh_prompt
      public_keys = Dir.glob("#{home_directory}/.ssh/*.pub").sort
      case public_keys.length
      when 0
        error("No SSH keys found")
        return nil
      when 1
        display "Found an SSH public key at #{public_keys.first}"
        display "Would you like to upload it to Heroku? [Yn] ", false
        return ask.strip.downcase =~ /^n/ ? nil : public_keys.first
      else
        display "Found the following SSH public keys:"
        public_keys.each_with_index do |key, index|
          display "#{index+1}) #{File.basename(key)}"
        end
        display "Which would you like to use with your Heroku account? ", false
        choice = ask.to_i - 1
        chosen = public_keys[choice]
        if choice == -1 || chosen.nil?
          error("Invalid choice")
        end
        return chosen
      end
    end

    def generate_ssh_key(keyfile)
      ssh_dir = File.dirname(keyfile)
      FileUtils.mkdir_p ssh_dir, :mode => 0700
      output = `ssh-keygen -t rsa -N "" -f \"#{keyfile}\" 2>&1`
      if ! $?.success?
        error("Could not generate key: #{output}")
      end
    end

    def associate_key(key)
      action("Uploading SSH public key #{key}") do
        if File.exists?(key)
          api.post_key(File.read(key))
        else
          error("Could not upload SSH public key: key file '" + key + "' does not exist")
        end
      end
    end

    def retry_login?
      @login_attempts ||= 0
      @login_attempts += 1
      @login_attempts < 3
    end

    def base_host(host)
      parts = URI.parse(full_host(host)).host.split(".")
      return parts.first if parts.size == 1
      parts[-2..-1].join(".")
    end

    def full_host(host)
      (host =~ /^http/) ? host : "https://api.#{host}"
    end

    def verify_host?(host)
      return false if ENV["HEROKU_SSL_VERIFY"] == "disable"
      base_host(host) == "heroku.com"
    end

    protected

    def default_params
      uri = URI.parse(full_host(host))
      params = {
        :headers          => {'User-Agent' => Heroku.user_agent},
        :host             => uri.host,
        :port             => uri.port.to_s,
        :scheme           => uri.scheme,
        :ssl_verify_peer  => verify_host?(host)
      }
      params[:instrumentor] = HTTPInstrumentor if debugging?

      params
    end
  end
end
