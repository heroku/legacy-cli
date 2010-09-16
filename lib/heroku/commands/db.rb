require 'yaml'
require 'logger'

module Heroku::Command
  class Db < BaseWithApp
    def push
      load_taps
      opts = parse_taps_opts

      display("Warning: Data in the app '#{app}' will be overwritten and will not be recoverable.")

      if extract_option("--force") || confirm
        taps_client(:push, opts)
      end
    end

    def pull
      load_taps
      opts = parse_taps_opts

      display("Warning: Data in the database '#{opts[:database_url]}' will be overwritten and will not be recoverable.")

      if extract_option("--force") || confirm
        taps_client(:pull, opts)
      end
    end

    def reset
      if !autodetected_app
        info = heroku.info(app)
        url  = info[:domain_name] || "http://#{info[:name]}.#{heroku.host}/"

        display("Warning: All data in the '#{app}' database will be erased and will not be recoverable.")

        if confirm
          heroku.database_reset(app)
          display "Database reset for '#{app}' (#{url})"
        end
      else
        display "Set the app you want to reset the database for by adding --app <app name> to this command"
      end
    end

    protected

    def parse_database_yml
      return "" unless File.exists?(Dir.pwd + '/config/database.yml')

      environment = ENV['RAILS_ENV'] || ENV['MERB_ENV'] || ENV['RACK_ENV']
      environment = 'development' if environment.nil? or environment.empty?

      conf = YAML.load(File.read(Dir.pwd + '/config/database.yml'))[environment]
      case conf['adapter']
        when 'sqlite3'
          return "sqlite://#{conf['database']}"
        when 'postgresql'
          uri_hash = conf_to_uri_hash(conf)
          uri_hash['scheme'] = 'postgres'
          return uri_hash_to_url(uri_hash)
        else
          return uri_hash_to_url(conf_to_uri_hash(conf))
      end
    rescue Exception => ex
      puts "Error parsing database.yml: #{ex.message}"
      puts ex.backtrace
      ""
    end

    def conf_to_uri_hash(conf)
      uri = {}
      uri['scheme'] = conf['adapter']
      uri['username'] = conf['user'] || conf['username']
      uri['password'] = conf['password']
      uri['host'] = conf['host'] || conf['hostname']
      uri['port'] = conf['port']
      uri['path'] = conf['database']

      conf['encoding'] = 'utf8' if conf['encoding'] == 'unicode' or conf['encoding'].nil?
      uri['query'] = "encoding=#{conf['encoding']}"

      uri
    end

    def userinfo_from_uri(uri)
      username = uri['username'].to_s
      password = uri['password'].to_s
      return nil if username == ''

      userinfo  = ""
      userinfo << username
      userinfo << ":" << password if password.length > 0
      userinfo
    end

    def uri_hash_to_url(uri)
      uri_parts = {
        :scheme   => uri['scheme'],
        :userinfo => userinfo_from_uri(uri),
        :password => uri['password'],
        :host     => uri['host'] || '127.0.0.1',
        :port     => uri['port'],
        :path     => "/%s" % uri['path'],
        :query    => uri['query'],
      }

      URI::Generic.build(uri_parts).to_s
    end

    def parse_taps_opts
      opts = {}
      opts[:default_chunksize] = extract_option("--chunksize") || 1000
      opts[:default_chunksize] = opts[:default_chunksize].to_i rescue 1000

      if filter = extract_option("--filter")
        opts[:table_filter] = filter
      elsif tables = extract_option("--tables")
        r_tables = tables.split(",").collect { |t| "^#{t.strip}$" }
        opts[:table_filter] = "(#{r_tables.join("|")})"
      end

      if extract_option("--disable-compression")
        opts[:disable_compression] = true
      end

      if resume_file = extract_option("--resume-filename")
        opts[:resume_filename] = resume_file
      end

      opts[:indexes_first] = !extract_option("--indexes-last")

      opts[:database_url] = args.shift.strip rescue ''
      if opts[:database_url] == ''
        opts[:database_url] = parse_database_yml
        display "Auto-detected local database: #{opts[:database_url]}" if opts[:database_url] != ''
      end
      raise(CommandFailed, "Invalid database url") if opts[:database_url] == ''

      if extract_option("--debug")
        Taps.log.level = Logger::DEBUG
      end

      # setting local timezone equal to Heroku timezone allowing TAPS to
      # correctly transfer datetime fields between databases
      ENV['TZ'] = 'America/Los_Angeles'
      opts
    end

    def taps_client(op, opts)
      Taps::Config.verify_database_url(opts[:database_url])
      if opts[:resume_filename]
        Taps::Cli.new([]).clientresumexfer(op, opts)
      else
        info = heroku.database_session(app)

        # TODO: this should be done API-side
        if RUBY_VERSION =~ /^1\.9/
          info["url"].gsub!('taps3.heroku.com', 'taps19.heroku.com')
        end

        opts[:remote_url] = info['url']
        opts[:session_uri] = info['session']
        Taps::Cli.new([]).clientxfer(op, opts)
      end
    end

    def load_taps
      require 'taps/operation'
      require 'taps/cli'
      error "The heroku gem requires taps 0.3" unless Taps.version =~ /^0.3/
      display "Loaded Taps v#{Taps.version}"
    rescue LoadError
      message  = "Taps 0.3 Load Error: #{$!.message}\n"
      message << "You may need to install or update the taps gem to use db commands.\n"
      message << "On most systems this will be:\n\nsudo gem install taps"
      error message
    end
  end
end
