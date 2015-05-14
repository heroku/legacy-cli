require "heroku/helpers/addons/api"

module Heroku::Helpers
  module Addons
    module Resolve
      include Heroku::Helpers::Addons::API

      UUID         = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
      ATTACHMENT   = /^(?:([a-z][a-z0-9-]+)::)?([A-Z][A-Z0-9_]+)$/
      RESOURCE     = /^@?([a-z][a-z0-9-]+)$/
      SERVICE_PLAN = /^(?:([a-z0-9_-]+):)?([a-z0-9_-]+)$/ # service / service:plan

      class AddonDoesNotExistError < Heroku::API::Errors::Error
      end

      # Finds attachments that match provided identifier.
      #
      # Always returns an Array of 0 or more results.
      def resolve_attachment(identifier, &filter)
        results = case identifier
        when UUID
          [get_attachment(identifier)].compact
        when ATTACHMENT
          app  = $1 || self.app # "app::..." or current app
          name = $2

          attachment = begin
            get_attachment(name, :app => app)
          rescue Heroku::API::Errors::NotFound
          end

          return [attachment] if attachment

          get_attachments(:app => app).select { |att| att["name"][name] }
        else
          []
        end

        filter ? results.select(&filter) : results
      end

      # Finds a single attachment unambiguously given an identifier.
      #
      # Returns an attachment hash or exits with an error.
      def resolve_attachment!(identifier, &filter)
        results = resolve_attachment(identifier, &filter)

        case results.count
        when 1
          results[0]
        when 0
          error("Can not find attachment with #{identifier.inspect}")
        else
          app = results.first['app']['name']
          error("Multiple attachments on #{app} match #{identifier.inspect}.\n" +
                "Did you mean one of:\n\n" +
                results.map { |att| "- #{att['name']}" }.join("\n"))
        end
      end

      # Finds add-ons that match provided identifier.
      #
      # Supports:
      #   * add-on resource UUID
      #   * add-on resource name (@my-db / my-db)
      #   * attachment name (other-app::ATTACHMENT / ATTACHMENT on current app)
      #   * service name
      #   * service:plan name
      #
      # Returns an array in every case except for when using a service name for an
      # non-existent add-on. In that case, the error message is returned.
      #
      def resolve_addon(identifier, &filter)
        results = case identifier
        when UUID
          return [get_addon(identifier)].compact
        when ATTACHMENT
          # identifier -> Array[Attachment] -> uniq Array[Addon]
          matches = resolve_attachment(identifier)
          matches.
            map { |att| att['addon']['id'] }.
            uniq.
            map { |addon_id| get_addon(addon_id) }
        else # try both resource and service identifiers, because they look similar
          if identifier =~ RESOURCE
            name = $1

            addon = begin
              get_addon(name)
            rescue Heroku::API::Errors::Forbidden
              # treat permission error as no match because there might exist a
              # resource on someone else's app that has a name which
              # corresponds to a service name that we wish to check below (e.g.
              # "memcachier")
            end

            return [addon] if addon
          end

          if identifier =~ SERVICE_PLAN
            service_name, plan_name = *[$1, $2].compact
            full_plan_name = [service_name, plan_name].join(':') if plan_name

            addons = get_addons(:app => app).select do |addon|
              addon['addon_service']['name'] == service_name &&          # match service
                [nil, addon['plan']['name']].include?(full_plan_name) && # match plan, IFF specified
                addon['app']['name'] == app                              # /apps/:id/addons returns un-owned add-ons
            end

            return addons
          end

          []
        end

        filter ? results.select(&filter) : results
      end

      # Finds a single add-on unambiguously given an identifier.
      #
      # Returns an add-on hash or exits with an error.
      def resolve_addon!(identifier, &filter)
        results = resolve_addon(identifier, &filter)

        case results.count
        when 1
          results[0]
        when 0
          error("Can not find add-on with #{identifier.inspect}")
        else
          error("Multiple add-ons match #{identifier.inspect}.\n" +
                "Use the name of add-on resource:\n\n" +
                results.map { |a| "- #{a['name']} (#{a['plan']['name']})" }.join("\n"))
        end
      end
    end
  end
end
