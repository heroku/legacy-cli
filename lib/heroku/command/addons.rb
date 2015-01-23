require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"

module Heroku::Command

  # manage addon resources
  #
  class Addons < Base

    include Heroku::Helpers::HerokuPostgresql

    # addons
    #
    # list installed addons
    #
    def index
      validate_arguments!

      addons = api.request(
        :expects  => [200, 206],
        :headers  => { "Accept" => "application/vnd.heroku+json; version=edge" },
        :method   => :get,
        :path     => "/apps/#{app}/addons"
      ).body

      attachments = api.request(
        :expects  => [200, 206],
        :headers  => { "Accept" => "application/vnd.heroku+json; version=edge" },
        :method   => :get,
        :path     => "/apps/#{app}/addon-attachments"
      ).body

      attachments_by_resource = {}
      attachments.each do |attachment|
        next unless attachment["app"]["name"] == app
        addon_uuid = attachment["addon"]["id"]
        attachments_by_resource["#{addon_uuid}"] ||= []
        attachments_by_resource["#{addon_uuid}"] << attachment['name']
      end

      if addons.empty?
        display("#{app} has no add-ons.")
      else
        styled_header("#{app} Add-on Resources")
        styled_array(addons.map do |addon|
          addon_name = addon['name'].downcase
          [
            addon['plan']['name'],
            "@#{addon_name}",
            attachments_by_resource[addon['id']].join(", ")
          ]
        end)
      end
    end

    # addons:plans
    #
    # list all available add-on plans
    #
    # --region REGION      # specify a region for add-on plan availability
    #
    #Example:
    #
    # $ heroku addons:plans --region eu
    # === available
    # adept-scale:battleship, corvette...
    # adminium:enterprise, petproject...
    #
    def plans
      addons = heroku.addons(options)
      if addons.empty?
        display "No add-ons available currently"
      else
        partitioned_addons = partition_addons(addons)
        partitioned_addons.each do |key, addons|
          partitioned_addons[key] = format_for_display(addons)
        end
        display_object(partitioned_addons)
      end
    end

    alias_command "addons:list", "addons:plans"

    # addons:create ADDON
    #
    def create
    end
    # addons:create PLAN
    #
    # create an add-on resource
    #
    # --name NAME             # (optional) name for the resource
    # --as ATTACHMENT_NAME    # (optional) name for the initial add-on attachment
    # --confirm APP_NAME      # (optional) ovewrite existing config vars or existing add-on attachments
    #
    def create
      if current_command == "add"
        return deprecate("`heroku #{current_command} has been deprecated. Please use `heroku addons:create` instead.")
      end

      addon = args.shift
      raise CommandFailed.new("Missing add-on name") if addon.nil? || %w{--fork --follow --rollback}.include?(addon)
      config = parse_options(args)

      service_name, plan_name = addon.split(":")

      # TODO mdg:
      # - Stop special-casing HPG
      # - Use resource identifiers instead of attachment identifiers
      # For Heroku Postgres, if no plan is specified with fork/follow/rollback,
      # default to the plan of the current postgresql plan
      if service_name =~ /heroku-postgresql/
        hpg_translate_db_opts_to_urls(addon, config)

        hpg_flag = %w{rollback fork follow}.detect { |flag| config.keys.include?(flag) }
        if plan_name.nil? && config[hpg_flag] =~ /^postgres:\/\//
          raise CommandFailed.new("Cross application database Forking/Following requires you specify a plan type")
        elsif (hpg_flag && plan_name.nil?)
          resolver = Resolver.new(app, api)
          addon = addon + ':' + resolver.resolve(config[hpg_flag]).plan_name
        end
      end

      addon_name = options.has_key?(:name) ? options[:name] : service_name

      action("Creating #{addon_name.downcase}") do
        addon = api.request(
          :body     => json_encode({
            "attachment" => { "name" => options[:as] },
            "config"     => config,
            "name"       => options[:name],
            "confirm"    => options[:confirm],
            "plan"       => { "name" => addon }
          }),
          :expects  => 201,
          :headers  => { "Accept" => "application/vnd.heroku+json; version=edge" },
          :method   => :post,
          :path     => "/apps/#{app}/addons"
        ).body

        @status = api.get_release(app, 'current').body['name']
      end

      action("Adding #{addon['name'].downcase} to #{app}") {}
      action("Setting #{addon['config_vars'].join(', ')} and restarting #{app}") {}

      #display resource['provider_data']['message'] unless resource['provider_data']['message'].strip == ""

      display("Use `heroku addons:docs #{addon['plan']['name'].split(':').first}` to view documentation.")
    end

    # addons:remove ADDON
    #
    def remove
      deprecate("`heroku #{current_command} has been deprecated. Please use `heroku addons:destroy` instead.")
    end

    # addons:upgrade ADDON
    #
    # upgrade an existing addon
    #
    def upgrade
      configure_addon('Upgrading to') do |addon, config|
        heroku.upgrade_addon(app, addon, config)
      end
    end

    # addons:downgrade ADDON
    #
    # downgrade an existing addon
    #
    def downgrade
      configure_addon('Downgrading to') do |addon, config|
        heroku.upgrade_addon(app, addon, config)
      end
    end

    # addons:remove ADDON1 [ADDON2 ...]
    #
    # uninstall one or more addons
    #
    def destroy
      addon = args.shift
      raise CommandFailed.new("Missing add-on name") if addon.nil?

      return unless confirm_command

      # TODO mdg: extract to other methods as well
      addon = addon.dup.sub(/^@/, '')

      addon_attachments = api.request(
        :expects => [200, 206],
        :headers  => { "Accept" => "application/vnd.heroku+json; version=edge" },
        :method   => :get,
        :path     => "/apps/#{app}/addon-attachments"
      ).body.keep_if do |attachment|
        attachment['addon']['name'] == addon
      end

      # TODO mdg: Get config vars correctly to display during unsetting
      addon_attachments.each do |attachment|
        action("Removing #{addon} as #{attachment['name']} from #{app}") {}
        #action("Unsetting #{var_name} and restarting #{app}") {}
      end

      @status = api.get_release(app, 'current').body['name']

      action("Destroying #{addon} on #{app}") do
        api.request(
          :body     => json_encode({
            "force" => options[:force],
          }),
          :expects  => 200..300,
          :headers  => { "Accept" => "application/vnd.heroku+json; version=edge" },
          :method   => :delete,
          :path     => "/apps/#{app}/addons/#{addon}"
        )
      end
    end

    # addons:docs ADDON
    #
    # open an addon's documentation in your browser
    #
    def docs
      unless addon = shift_argument
        error("Usage: heroku addons:docs ADDON\nMust specify ADDON to open docs for.")
      end
      validate_arguments!

      addon_names = api.get_addons.body.map {|a| a['name']}
      addon_types = addon_names.map {|name| name.split(':').first}.uniq

      name_matches = addon_names.select {|name| name =~ /^#{addon}/}
      type_matches = addon_types.select {|name| name =~ /^#{addon}/}

      if name_matches.include?(addon) || type_matches.include?(addon)
        type_matches = [addon]
      end

      case type_matches.length
      when 0 then
        error([
          "`#{addon}` is not a heroku add-on.",
          suggestion(addon, addon_names + addon_types),
          "See `heroku addons:list` for all available addons."
        ].compact.join("\n"))
      when 1
        addon_type = type_matches.first
        launchy("Opening #{addon_type} docs", addon_docs_url(addon_type))
      else
        error("Ambiguous addon name: #{addon}\nPerhaps you meant #{name_matches[0...-1].map {|match| "`#{match}`"}.join(', ')} or `#{name_matches.last}`.\n")
      end
    end

    # addons:open ADDON
    #
    # open an addon's dashboard in your browser
    #
    def open
      unless addon = shift_argument
        error("Usage: heroku addons:open ADDON\nMust specify ADDON to open.")
      end
      validate_arguments!

      app_addons = api.get_addons(app).body.map {|a| a['name']}
      matches = app_addons.select {|a| a =~ /^#{addon}/}.sort

      case matches.length
      when 0 then
        addon_names = api.get_addons.body.map {|a| a['name']}
        if addon_names.any? {|name| name =~ /^#{addon}/}
          error("Addon not installed: #{addon}")
        else
          error([
            "`#{addon}` is not a heroku add-on.",
            suggestion(addon, addon_names + addon_names.map {|name| name.split(':').first}.uniq),
            "See `heroku addons:list` for all available addons."
          ].compact.join("\n"))
        end
      when 1 then
        addon_to_open = matches.first
        launchy("Opening #{addon_to_open} for #{app}", app_addon_url(addon_to_open))
      else
        error("Ambiguous addon name: #{addon}\nPerhaps you meant #{matches[0...-1].map {|match| "`#{match}`"}.join(', ')} or `#{matches.last}`.\n")
      end
    end

    private

    def addon_docs_url(addon)
      "https://devcenter.#{heroku.host}/articles/#{addon.split(':').first}"
    end

    def app_addon_url(addon)
      "https://addons-sso.heroku.com/apps/#{app}/addons/#{addon}"
    end

    def partition_addons(addons)
      addons.group_by{ |a| (a["state"] == "public" ? "available" : a["state"]) }
    end

    def format_for_display(addons)
      grouped = addons.inject({}) do |base, addon|
        group, short = addon['name'].split(':')
        base[group] ||= []
        base[group] << addon.merge('short' => short)
        base
      end
      grouped.keys.sort.map do |name|
        addons = grouped[name]
        row = name.dup
        if addons.any? { |a| a['short'] }
          row << ':'
          size = row.size
          stop = false
          row << addons.map { |a| a['short'] }.compact.sort.map do |short|
            size += short.size
            if size < 31
              short
            else
              stop = true
              nil
            end
          end.compact.join(', ')
          row << '...' if stop
        end
        row
      end
    end

    def addon_run
      response = yield

      if response
        price = "(#{ response['price'] })" if response['price']

        if response['message'] =~ /(Attached as [A-Z0-9_]+)\n(.*)/m
          attachment = $1
          message = $2
        else
          attachment = nil
          message = response['message']
        end

        begin
          release = api.get_release(app, 'current').body
          release = release['name']
        rescue Heroku::API::Errors::Error
          release = nil
        end
      end

      status [ release, price ].compact.join(' ')
      { :attachment => attachment, :message => message }
    end

    def configure_addon(label, &install_or_upgrade)
      addon = args.shift
      raise CommandFailed.new("Missing add-on name") if addon.nil? || %w{--fork --follow --rollback}.include?(addon)

      config = parse_options(args)
      addon_name, plan = addon.split(':')


      # For Heroku Postgres, if no plan is specified with fork/follow/rollback,
      # default to the plan of the current postgresql plan
      if addon_name =~ /heroku-postgresql/ then
        hpg_flag  = %w{rollback fork follow}.select {|flag| config.keys.include? flag}.first
        if plan.nil? &&  config[hpg_flag] =~ /^postgres:\/\// then
          raise CommandFailed.new("Cross application database Forking/Following requires you specify a plan type")
        elsif (hpg_flag && plan.nil?) then
          resolver = Resolver.new(app, api)
          addon = addon + ':' + resolver.resolve(config[hpg_flag]).plan
        end
      end

      hpg_translate_db_opts_to_urls(addon, config)

      config.merge!(:confirm => app) if app == options[:confirm]
      raise CommandFailed.new("Unexpected arguments: #{args.join(' ')}") unless args.empty?

      messages = nil
      action("#{label} #{addon} on #{app}") do
        messages = addon_run { install_or_upgrade.call(addon, config) }
      end
      display(messages[:attachment]) unless messages[:attachment].to_s.strip == ""
      display(messages[:message]) unless messages[:message].to_s.strip == ""

      display("Use `heroku addons:docs #{addon_name}` to view documentation.")
    end

    #this will clean up when we officially deprecate
    def parse_options(args)
      config = {}
      deprecated_args = []
      flag = /^--/

      args.size.times do
        break if args.empty?
        peek = args.first
        next unless peek && (peek.match(flag) || peek.match(/=/))
        arg  = args.shift
        peek = args.first
        key  = arg
        if key.match(/=/)
          deprecated_args << key unless key.match(flag)
          key, value = key.split('=', 2)
        elsif peek.nil? || peek.match(flag)
          value = true
        else
          value = args.shift
        end
        value = true if value == 'true'
        config[key.sub(flag, '')] = value

        if !deprecated_args.empty?
          out_string = deprecated_args.map{|a| "--#{a}"}.join(' ')
          display("Warning: non-unix style params have been deprecated, use #{out_string} instead")
        end
      end

      config
    end

  end
end
