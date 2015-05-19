module Support
  module Addons
    def build_addon(addon={})
      addon_id = addon[:id] || SecureRandom.uuid
      {
        config_vars: addon.fetch(:config_vars, []),
        created_at:  Time.now,
        id:          addon_id,
        name:        addon[:name] || addon_name(addon[:plan][:name]),

        addon_service: {
          id:   SecureRandom.uuid,
        }.merge(addon.fetch(:addon_service, {})),

        plan: {
          id: SecureRandom.uuid,
          price: {
            cents: 0, unit: 'month'
          }
        }.merge(addon.fetch(:plan, {})),

        app: {
          id: SecureRandom.uuid,
        }.merge(addon.fetch(:app, {})),

        provider_id: addon[:provider_id],
        updated_at:  Time.now,
        web_url:     "https://addons-sso.heroku.com/apps/#{addon[:app][:name]}/addons/#{addon_id}"
      }
    end

    def build_attachment(attachment={})
      {
        addon: {
          id: SecureRandom.uuid,
        }.merge(attachment.fetch(:addon, {})),

        app: {
          id: SecureRandom.uuid,
        }.merge(attachment.fetch(:app, {})),

        created_at: Time.now,
        id:         attachment.fetch(:id, SecureRandom.uuid),
        name:       attachment[:name],
        updated_at: Time.now
      }
    end

    # Helpers generate Hashes with symbol keys. When using as outside of
    # a request stub, we need them all the be strings. See "understands foo=baz".
    def stringify(options)
      MultiJson.decode(MultiJson.encode(options))
    end
  end
end
