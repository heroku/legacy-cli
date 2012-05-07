require "heroku/helpers"

module Heroku::Helpers::HerokuPostgresql

  include Heroku::Helpers

  private

  def config_vars
    @config_vars ||= heroku.config_vars(app)
  end

  def name_from_url(db_url)
    name = reverse_resolve(db_url)
    if name
      Resolver.new(name, config_vars).pretty_name
    else
      "Database on #{URI.parse(db_url).host}"
    end
  end

  def reverse_resolve(db_url)
    pair = config_vars.detect do |name, url|
      url == db_url && name != "DATABASE_URL"
    end
    pair && pair.first
  end

  def resolve_db(options={})
    db_id = db_flag
    unless db_id
      if options[:allow_default]
        db_id = "DATABASE"
      else
        error("Usage: heroku #{options[:required]} <DATABASE>") if options[:required]
      end
    end

    resolver = Resolver.new(db_id, config_vars)
    display(resolver.message) if resolver.message
    abort_with_database_list(db_id) unless resolver.url

    return resolver
  end

  def abort_with_database_list(failed_id)
    output_with_bang "Could not resolve database #{failed_id}"
    output_with_bang "\nAvailable databases: "
    Resolver.all(config_vars).each do |db|
      output_with_bang "#{db[:pretty_name]}"
    end
    abort
  end

  def specified_db?
    db_flag
  end

  def db_flag
    @db_flag ||= args.shift
  end

  def specified_db_or_all
    if specified_db?
      yield resolve_db
    else
      Resolver.all(config_vars).each { |db| yield db }
    end
  end

  def self.addon_name
    ENV['HEROKU_POSTGRESQL_ADDON_NAME'] || 'heroku-postgresql'
  end

  def deprecate_dash_dash_db(name)
    return unless args.include? "--db"
    output_with_bang "The --db option has been deprecated"
    usage = Heroku::Command::Help.usage_for_command(name)
    error "#{usage}"
  end

  def spinner(ticks)
    %w(/ - \\ |)[ticks % 4]
  end

  def ticking
    ticks = 0
    loop do
      yield(ticks)
      ticks +=1
      sleep 1
    end
  end

  def display_info(label, info)
    display(format("%-12s %s", label, info))
  end

  def translate_fork_and_follow(addon, config)
    if addon =~ /^#{Heroku::Helpers::HerokuPostgresql.addon_name}/
      %w[fork follow].each do |opt|
        if val = config[opt]
          unless val.is_a?(String)
            error("--#{opt} requires a database argument")
          end
          resolved = Resolver.new(val, config_vars)
          display resolved.message if resolved.message
          abort_with_database_list(val) unless resolved[:url]
          config[opt] = resolved[:url]
        end
      end
    end
  end

  #
  # Resolver class
  #
  class Resolver

    include Heroku::Helpers::HerokuPostgresql

    attr_reader :url, :db_id

    def initialize(db_id, config_vars)
      raise ArgumentError unless db_id
      @db_id, @config_vars = db_id, config_vars
      @db_id = @db_id.upcase unless @db_id =~ /\Apostgres/
      @messages = []
      parse_config
      resolve
    end

    def message
      @messages.join("\n") unless @messages.empty?
    end

    def [](arg)
      { :name => name,
        :url => url,
        :pretty_name => pretty_name,
        :default => default?
      }[arg]
    end

    def name
      db_id
    end

    def pretty_name
      "#{db_id}#{ " (DATABASE_URL)" if default? }"
    end

    def self.all(config_vars)
      parsed = parse_config(config_vars)
      default = parsed['DATABASE']
      dbs = []
      parsed.reject{|k,v| k == 'DATABASE'}.each do |name, url|
        dbs << {:name => name, :url => url, :default => url==default, :pretty_name => "#{name}#{' (DATABASE_URL)' if url==default}"}
      end
      dbs.sort {|a,b| a[:default] ? -1 : a[:name] <=> b[:name] }
    end

    private

    def parse_config
      @dbs = self.class.parse_config(@config_vars)
    end

    def self.addon_prefix
      ENV["HEROKU_POSTGRESQL_ADDON_PREFIX"] || "HEROKU_POSTGRESQL"
    end

    def self.parse_config(config_vars)
      dbs = {}
      config_vars.each do |key,val|
        case key
        when "DATABASE_URL"
          dbs['DATABASE'] = val
        when 'SHARED_DATABASE_URL'
          dbs['SHARED_DATABASE'] = val
        when /^(#{addon_prefix}\w+)_URL$/
          dbs[$1] = val
        end
      end
      return dbs
    end

    def default?
      url && url == @dbs['DATABASE']
    end

    def resolve
      postgres_url_check
      url_deprecation_check
      default_database_check
      color_only_check
      if @dbs.empty?
        error("Your app has no databases.")
        exit(1)
      end
      @url = @dbs[@db_id] unless @url
    end

    def postgres_url_check
      return unless @db_id.downcase =~ /^postgres:\/\//
      @url = @db_id
      @db_id = name_from_url(@url)
    end

    def url_deprecation_check
      return unless @db_id =~ /(\w+)_URL$/
      old_id = @db_id
      @db_id = $+
      @messages << "#{old_id} is deprecated, please use #{@db_id}"
    end

    def default_database_check
      return unless @db_id == 'DATABASE'
      dbs = @dbs.find { |k,v|
        v == @dbs['DATABASE'] && k != 'DATABASE'
      }

      if dbs
        @db_id = dbs.first
      else
        @messages << "DATABASE_URL does not match any of your databases"
      end
    end

    def color_only_check
      color_key = "#{self.class.addon_prefix}_#{@db_id}"
      if @dbs[color_key]
        @db_id = color_key
      end
    end
  end
end
