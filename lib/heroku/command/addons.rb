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

      installed = api.get_addons(app).body
      if installed.empty?
        display("#{app} has no add-ons.")
      else
        available, pending = installed.partition { |a| a['configured'] }

        unless available.empty?
          styled_header("#{app} Configured Add-ons")
          styled_array(available.map do |a|
            [a['name'], a['attachment_name'] || '']
          end)
        end

        unless pending.empty?
          styled_header("#{app} Add-ons to Configure")
          styled_array(pending.map do |a|
            [a['name'], app_addon_url(a['name'])]
          end)
        end
      end
    end

    # addons:list
    #
    # list all available addons
    #
    def list
      addons = heroku.addons
      if addons.empty?
        display "No addons available currently"
      else
        partitioned_addons = partition_addons(addons)
        partitioned_addons.each do |key, addons|
          partitioned_addons[key] = format_for_display(addons)
        end
        display_object(partitioned_addons)
      end
    end

    # addons:add ADDON
    #
    # install an addon
    #
    def add
      configure_addon('Adding') do |addon, config|
        heroku.install_addon(app, addon, config)
      end
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
    def remove
      return unless confirm_command

      args.each do |name|
        messages = nil
        action("Removing #{name} on #{app}") do
          messages = addon_run { heroku.uninstall_addon(app, name, :confirm => app) }
        end
        display(messages[:attachment]) if messages[:attachment]
        display(messages[:message]) if messages[:message]
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
      "https://api.#{heroku.host}/apps/#{app}/addons/#{addon}"
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
    rescue RestClient::ResourceNotFound => e
      error Heroku::Command.extract_error(e.http_body) {
        e.http_body =~ /^([\w\s]+ not found).?$/ ? $1 : "Resource not found"
      }
    rescue RestClient::Locked => ex
      raise
    rescue RestClient::RequestFailed => e
      retry if e.http_code == 402 && confirm_billing
      error Heroku::Command.extract_error(e.http_body)
    end

    def configure_addon(label, &install_or_upgrade)
      addon = args.shift
      raise CommandFailed.new("Missing add-on name") if addon.nil? || ["--fork", "--follow"].include?(addon)

      config = parse_options(args)
      config.merge!(:confirm => app) if app == options[:confirm]
      raise CommandFailed.new("Unexpected arguments: #{args.join(' ')}") unless args.empty?

      hpg_translate_fork_and_follow(addon, config)

      messages = nil
      action("#{label} #{addon} on #{app}") do
        messages = addon_run { install_or_upgrade.call(addon, config) }
      end
      display(messages[:attachment]) unless messages[:attachment].to_s.strip == ""
      display(messages[:message]) unless messages[:message].to_s.strip == ""

      display("Use `heroku addons:docs #{addon}` to view documentation.")
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
