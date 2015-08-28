require "heroku/helpers/addons/api"

module Heroku::Helpers
  module Addons
    module Resolve
      include Heroku::Helpers::Addons::API

      def resolve_addon!(identifier)
        if identifier !~ /::/ && (app = maybe_app)
          get_addon(identifier, app: app)
        end || get_addon!(identifier)
      end

      def resolve_attachment!(identifier)
        if identifier !~ /::/ && (app = maybe_app)
          get_attachment(identifier, app: app)
        end || get_attachment!(identifier)
      end

      def maybe_app
        app
      rescue Heroku::Command::CommandFailed
        nil
      end
    end
  end
end
