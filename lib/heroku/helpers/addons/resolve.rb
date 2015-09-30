require "heroku/helpers/addons/api"

module Heroku::Helpers
  module Addons
    module Resolve
      include Heroku::Helpers::Addons::API

      def resolve_addon!(identifier, app=maybe_app)
        if identifier !~ /::/ && app
          get_addon(identifier, app: app)
        end || get_addon!(identifier)
      end

      def resolve_attachment!(identifier, app=maybe_app)
        if identifier !~ /::/ && app
          get_attachment(identifier, app: app)
        end || get_attachment!(identifier)
      end

      private

      def maybe_app
        app
      rescue Heroku::Command::CommandFailed
        nil
      end
    end

    class Resolver < Struct.new(:api)
      include Resolve
    end
  end
end
