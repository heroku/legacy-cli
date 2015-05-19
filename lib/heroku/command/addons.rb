require "heroku/command/base"
require "heroku/helpers/heroku_postgresql"
require "heroku/helpers/addons/api"
require "heroku/helpers/addons/display"
require "heroku/helpers/addons/resolve"

module Heroku::Command

  # manage addon resources
  #
  class Addons < Base

    include Heroku::Helpers::HerokuPostgresql
    include Heroku::Helpers::Addons::API
    include Heroku::Helpers::Addons::Display
    include Heroku::Helpers::Addons::Resolve

    # addons [{--all,--app APP_NAME,--resource ADDON_NAME}]
    #
    # list installed add-ons
    #
    # NOTE: --all is the default unless in an application repository directory, in
    # which case --all is inferred.
    #
    # --all                  # list add-ons across all apps in account
    # --app APP_NAME         # list add-ons associated with a given app
    # --resource ADDON_NAME  # view details about add-on and all of its attachments
    #
    #Examples:
    #
    # $ heroku addons --all
    # $ heroku addons --app acme-inc-website
    # $ heroku addons --resource @acme-inc-database
    #
    def index
      validate_arguments!
      requires_preauth

      # Filters are mutually exclusive
      error("Can not use --all with --app")      if options[:app] && options[:all]
      error("Can not use --all with --resource") if options[:resource] && options[:all]
      error("Can not use --app with --resource") if options[:resource] && options[:app]

      app = (self.app rescue nil)
      if (resource = options[:resource])
        show_for_resource(resource)
      elsif app && !options[:all]
        show_for_app(app)
      else
        show_all
      end
    end

    # addons:services
    #
    # list all available add-on services
    def services
      if current_command == "addons:list"
        deprecate("`heroku #{current_command}` has been deprecated. Please use `heroku addons:services` instead.")
      end

      display_table(get_services, %w[name human_name state], %w[Slug Name State])
      display "\nSee plans with `heroku addons:plans SERVICE`"
    end

    alias_command "addons:list", "addons:services"

    # addons:plans SERVICE
    #
    # list all available plans for an add-on service
    def plans
      service = args.shift
      raise CommandFailed.new("Missing add-on service") if service.nil?

      service = get_service!(service)
      display_header("#{service['human_name']} Plans")

      plans = get_plans(:service => service['id'])

      plans = plans.sort_by { |p| [(!p['default']).to_s, p['price']['cents']] }.map do |plan|
        {
          "default"    => ('default' if plan['default']),
          "name"       => plan["name"],
          "human_name" => plan["human_name"],
          "price"      => format_price(plan["price"])
        }
      end

      display_table(plans, %w[default name human_name price], [nil, 'Slug', 'Name', 'Price'])
    end

    # addons:create {SERVICE,PLAN}
    #
    # create an add-on resource
    #
    # --name ADDON_NAME       # (optional) name for the add-on resource
    # --as ATTACHMENT_NAME    # (optional) name for the initial add-on attachment
    # --confirm APP_NAME      # (optional) ovewrite existing config vars or existing add-on attachments
    #
    def create
      if current_command == "addons:add"
        deprecate("`heroku #{current_command}` has been deprecated. Please use `heroku addons:create` instead.")
      end

      requires_preauth

      service_plan = expand_hpg_shorthand(args.shift)

      raise CommandFailed.new("Missing requested service or plan") if service_plan.nil? || %w{--fork --follow --rollback}.include?(service_plan)

      config = parse_options(args)
      raise CommandFailed.new("Unexpected arguments: #{args.join(' ')}") unless args.empty?

      addon = request(
        :body     => json_encode({
          "attachment" => { "name" => options[:as] },
          "config"     => config,
          "name"       => options[:name],
          "confirm"    => options[:confirm],
          "plan"       => { "name" => service_plan }
        }),
        :headers  => {
          # Temporary hack for getting provider messages while a cleaner
          # endpoint is designed to communicate this data.
          #
          # WARNING: Do not depend on this having any effect permanently.
          "Accept-Expansion" => "plan",
          "X-Heroku-Legacy-Provider-Messages" => "true"
        },
        :expects  => 201,
        :method   => :post,
        :path     => "/apps/#{app}/addons"
      )
      @status = "(#{format_price addon['plan']['price']})" if addon['plan'].has_key?('price')

      action("Creating #{addon['name'].downcase}") {}
      action("Adding #{addon['name'].downcase} to #{app}") {}

      if addon['config_vars'].any?
        action("Setting #{addon['config_vars'].join(', ')} and restarting #{app}") do
          @status = api.get_release(app, 'current').body['name']
        end
      end

      display addon['provision_message'] unless addon['provision_message'].to_s.strip == ""

      display("Use `heroku addons:docs #{addon['addon_service']['name']}` to view documentation.")
    end

    alias_command "addons:add", "addons:create"

    # addons:attach ADDON_NAME
    #
    # attach add-on resource to an app
    #
    # --as ATTACHMENT_NAME  # (optional) name for add-on attachment
    # --confirm APP_NAME    # overwrite existing add-on attachment with same name
    #
    def attach
      unless addon_name = args.shift
        error("Usage: heroku addons:attach ADDON_NAME\nMust specify add-on resource to attach.")
      end
      addon = resolve_addon!(addon_name)

      requires_preauth

      attachment_name = options[:as]

      msg = attachment_name ?
        "Attaching #{addon['name']} as #{attachment_name} to #{app}" :
        "Attaching #{addon['name']} to #{app}"

      display("#{msg}... ", false)

      response = api.request(
        :body     => json_encode({
          "app"     => {"name" => app},
          "addon"   => {"name" => addon['name']},
          "confirm" => options[:confirm],
          "name"    => attachment_name
        }),
        :expects  => [201, 422],
        :headers  => { "Accept" => "application/vnd.heroku+json; version=3" },
        :method   => :post,
        :path     => "/addon-attachments"
      )

      case response.status
      when 201
        display("done")
        action("Setting #{response.body["name"]} vars and restarting #{app}") do
          @status = api.get_release(app, 'current').body['name']
        end
      when 422 # add-on resource not found or cannot be attached
        display("failed")
        output_with_bang(response.body["message"])
        output_with_bang("List available resources with `heroku addons`.")
        output_with_bang("Provision a new add-on resource with `heroku addons:create ADDON_PLAN`.")
      end
    end

    # addons:detach ATTACHMENT_NAME
    #
    # detach add-on resource from an app
    #
    def detach
      attachment_name = args.shift
      raise CommandFailed.new("Missing add-on attachment name") if attachment_name.nil?
      requires_preauth

      addon_attachment = resolve_attachment!(attachment_name)

      attachment_name = addon_attachment['name'] # in case a UUID was passed in
      addon_name      = addon_attachment['addon']['name']
      app             = addon_attachment['app']['name']

      action("Removing #{attachment_name} attachment to #{addon_name} from #{app}") do
        api.request(
          :expects  => 200..300,
          :headers  => { "Accept" => "application/vnd.heroku+json; version=3" },
          :method   => :delete,
          :path     => "/addon-attachments/#{addon_attachment['id']}"
        ).body
      end
      action("Unsetting #{attachment_name} vars and restarting #{app}") do
        @status = api.get_release(app, 'current').body['name']
      end
    end

    # addons:upgrade ADDON_NAME ADDON_SERVICE:PLAN
    #
    # upgrade an existing add-on resource to PLAN
    #
    def upgrade
      addon_name, plan = args.shift, args.shift

      if addon_name && !plan # If invocated as `addons:Xgrade service:plan`
        deprecate("No add-on name specified (see `heroku help #{current_command}`)")

        addon = nil
        plan = addon_name
        service = plan.split(':').first

        action("Finding add-on from service #{service} on app #{app}") do
          # resolve with the service only, because the user has passed in the
          # *intended* plan, not the current plan.
          addon = resolve_addon!(service)
          addon_name = addon['name']
        end
        display "Found #{addon_name} (#{addon['plan']['name']}) on #{app}."
      else
        raise CommandFailed.new("Missing add-on name") if addon_name.nil?
        addon_name = addon_name.sub(/^@/, '')
      end

      raise CommandFailed.new("Missing add-on plan") if plan.nil?

      action("Changing #{addon_name} plan to #{plan}") do
        addon = api.request(
          :body     => json_encode({
            "plan"   => { "name" => plan }
          }),
          :expects  => 200..300,
          :headers  => {
            "Accept" => "application/vnd.heroku+json; version=3",
            "Accept-Expansion" => "plan"
          },
          :method   => :patch,
          :path     => "/apps/#{app}/addons/#{addon_name}"
        ).body
        @status = "(#{format_price addon['plan']['price']})" if addon['plan'].has_key?('price')
      end
    end

    # addons:downgrade ADDON_NAME ADDON_SERVICE:PLAN
    #
    # downgrade an existing add-on resource to PLAN
    #
    def downgrade
      upgrade
    end

    # addons:destroy ADDON_NAME [ADDON_NAME ...]
    #
    # destroy add-on resources
    #
    # -f, --force # allow destruction even if add-on is attached to other apps
    #
    def destroy
      if current_command == "addons:remove"
        deprecate("`heroku #{current_command}` has been deprecated. Please use `heroku addons:destroy` instead.")
      end

      raise CommandFailed.new("Missing add-on name") if args.empty?

      requires_preauth
      confirmed_apps = []

      while addon_name = args.shift
        addon = resolve_addon!(addon_name)
        app   = addon['app']

        unless confirmed_apps.include?(app['name'])
          return unless confirm_command(app['name'])
          confirmed_apps << app['name']
        end

        addon_attachments = get_attachments(:resource => addon['id'])

        action("Destroying #{addon['name']} on #{app['name']}") do
          addon = api.request(
            :body     => json_encode({
              "force" => options[:force],
            }),
            :expects  => 200..300,
            :headers  => {
              "Accept" => "application/vnd.heroku+json; version=3",
              "Accept-Expansion" => "plan"
            },
            :method   => :delete,
            :path     => "/apps/#{app['id']}/addons/#{addon['id']}"
          ).body
          @status = "(#{format_price addon['plan']['price']})" if addon['plan'].has_key?('price')
        end

        if addon['config_vars'].any? # litmus test for whether the add-on's attachments have vars
          # For each app that had an attachment, output a message indicating that
          # the app has been restarted any any associated vars have been removed.
          addon_attachments.group_by { |att| att['app']['name'] }.each do |app, attachments|
            names = attachments.map { |att| att['name'] }.join(', ')
            action("Removing vars for #{names} from #{app} and restarting") {
              @status = api.get_release(app, 'current').body['name']
            }
          end
        end
      end
    end

    alias_command "addons:remove", "addons:destroy"

    # addons:docs ADDON_NAME
    #
    # open an add-on's documentation in your browser
    #
    def docs
      unless identifier = shift_argument
        error("Usage: heroku addons:docs ADDON\nMust specify ADDON to open docs for.")
      end
      validate_arguments!

      # If it looks like a plan, optimistically open docs, otherwise try to
      # lookup a corresponding add-on and open the docs for its service.
      if identifier.include?(':')
        service = identifier.split(':')[0]
        launchy("Opening #{service} docs", addon_docs_url(service))
      else
        # searching by any number of things
        matches = resolve_addon(identifier)
        services = matches.map { |m| m['addon_service']['name'] }.uniq

        case services.count
        when 0
          # Optimistically open docs for whatever they passed in
          launchy("Opening #{identifier} docs", addon_docs_url(identifier))
        when 1
          service = services.first
          launchy("Opening #{service} docs", addon_docs_url(service))
        else
          error("Multiple add-ons match #{identifier.inspect}.\n" +
                "Use the name of one of the add-on resources:\n\n" +
                matches.map { |a| "- #{a['name']} (#{a['addon_service']['name']})" }.join("\n"))
        end
      end
    end

    # addons:open ADDON_NAME
    #
    # open an add-on's dashboard in your browser
    #
    def open
      unless addon_name = shift_argument
        error("Usage: heroku addons:open ADDON\nMust specify ADDON to open.")
      end
      validate_arguments!
      requires_preauth

      addon = resolve_addon!(addon_name)
      return addon if addon.is_a?(String)

      service = addon['addon_service']['name']
      launchy("Opening #{service} (#{addon['name']}) for #{addon['app']['name']}", addon["web_url"])
    end

    private

    def addon_docs_url(addon)
      "https://devcenter.#{heroku.host}/articles/#{addon.split(':').first}"
    end

    def expand_hpg_shorthand(addon_plan)
      if addon_plan =~ /\Ahpg:/
        addon_plan = "heroku-postgresql:#{addon_plan.split(':').last}"
      end
      if addon_plan =~ /\Aheroku-postgresql:[spe]\d+\z/
        addon_plan.gsub!(/:s/,':standard-')
        addon_plan.gsub!(/:p/,':premium-')
        addon_plan.gsub!(/:e/,':enterprise-')
      end
      addon_plan
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
