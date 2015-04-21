module Heroku::Helpers
  module Addons
    module API
      VERSION="3.switzerland".freeze

      def request(options = {})
        defaults = {
          :expects => 200,
          :headers => {},
          :method  => :get
        }
        options = defaults.merge(options)
        options[:headers]["Accept"] ||= "application/vnd.heroku+json; version=#{VERSION}"
        api.request(options).body
      end

      def request_list(options = {})
        options = options.dup
        options[:expects] = [200, 206, *options[:expects]].uniq

        request(options)
      end

      def get_attachments(options = {})
        request_list(:path => attachments_path(options))
      end

      def get_attachment!(identifier, options = {})
        request(:path => "#{attachments_path(options)}/#{identifier}")
      end

      def get_attachment(identifier, options = {})
        get_attachment!(identifier, options)
      rescue Heroku::API::Errors::NotFound
      end

      def get_addons(options = {})
        request_list(
          :headers => { 'Accept-Expansion' => 'plan' },
          :path    => addons_path(options)
        )
      end

      def get_addon!(identifier, options = {})
        request(
          :headers => { 'Accept-Expansion' => 'plan' },
          :path    => "#{addons_path(options)}/#{identifier}"
        )
      end

      def get_addon(identifier, options = {})
        get_addon!(identifier, options)
      rescue Heroku::API::Errors::NotFound
      end

      def get_service!(service)
        request(:path => "/addon-services/#{service}")
      end

      def get_service(service)
        get_service!
      rescue Heroku::API::Errors::NotFound
      end

      def get_services
        request_list(:path => "/addon-services")
      end

      def get_plans(options = {})
        path = options[:service] ?
          "/addon-services/#{options[:service]}/plans" :
          "/plans"

        request_list(:path => path)
      end

      private

      def addons_path(options)
        if app = options[:app]
          "/apps/#{app}/addons"
        else
          "/addons"
        end
      end

      def attachments_path(options)
        if resource = options[:resource]
          "/addons/#{resource}/addon-attachments"
        elsif app = options[:app]
          "/apps/#{app}/addon-attachments"
        else
          "/addon-attachments"
        end
      end
    end
  end
end
