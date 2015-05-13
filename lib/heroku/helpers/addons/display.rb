require "heroku/helpers/addons/api"

module Heroku::Helpers
  module Addons
    module Display
      include Heroku::Helpers::Addons::API

      # Shows details about and attachments for a specified resource. For example:
      #
      # $ heroku addons --resource practicing-nobly-1495
      # === Resource Info
      # Name:        practicing-nobly-1495
      # Plan:        heroku-postgresql:premium-yanari
      # Billing App: addons-reports
      # Price:       $200.00/month
      #
      # === Attachments
      # App             Name
      # --------------  ------------------------
      # addons          ADDONS_REPORTS
      # addons-reports  DATABASE
      # addons-reports  HEROKU_POSTGRESQL_SILVER
      def show_for_resource(identifier)
        styled_header("Resource Info")

        resource = resolve_addon!(identifier)

        styled_hash({
          'Name'        => resource['name'],
          'Plan'        => resource['plan']['name'],
          'Billing App' => resource['app']['name'],
          'Price'       => format_price(resource['plan']['price'])
        }, ['Name', 'Plan', 'Billing App', 'Price'])

        display("") # separate sections

        styled_header("Attachments")
        display_attachments(get_attachments(:resource => resource['id']), ['App', 'Name'])
      end

      # Shows all add-ons owned by and attachments attached to the provided app. For example:
      #
      # === Add-on Resources for bjeanes
      # Plan                     Name                    Price
      # -----------------------  ----------------------  -----
      # heroku-postgresql:dev    budding-busily-2230     free
      # memcachier-staging:test  sighing-ably-6278       free
      # memcachier-staging:test  rolling-carefully-8506  free
      # newrelic:wayne           unwinding-kindly-4330   free
      # pgbackups:plus           pgbackups-8071074       free
      #
      # === Add-on Attachments for bjeanes
      # Name                      Add-on                  Billing App
      # ------------------------  ----------------------  -----------
      # DATABASE                  budding-busily-2230     bjeanes
      # HEROKU_POSTGRESQL_VIOLET  budding-busily-2230     bjeanes
      # MEMCACHE                  sighing-ably-6278       bjeanes
      # MEMCACHIER_STAGING        rolling-carefully-8506  bjeanes
      # NEWRELIC                  unwinding-kindly-4330   bjeanes
      # PGBACKUPS                 pgbackups-8071074       bjeanes
      def show_for_app(app)
        styled_header("Resources for #{app}")

        addons = get_addons(:app => app).
          # the /apps/:id/addons endpoint can return more than just those owned
          # by the app, so filter:
          select { |addon| addon['app']['name'] == app }

        display_addons(addons, %w[Plan Name Price])

        display('') # separate sections

        styled_header("Attachments for #{app}")
        display_attachments(get_attachments(:app => app), ['Name', 'Add-on', 'Billing App'])
      end

      # Shows a table of all add-ons on the account. For example:
      #
      # === Add-on Resources
      # Plan                     Name                         Billing App     Price
      # -----------------------  ---------------------------  --------------  ------------
      # bugsnag:sagittaron       bugsnag-9174150              addons          $9.00/month
      # deployhooks:hipchat      deployhooks-hipchat-9852225  addons-staging  free
      # heroku-postgresql:crane  advising-fairly-3183         ion-bo          $50.00/month
      # newrelic:wayne           unwinding-kindly-4330        bjeanes         free
      def show_all
        styled_header('Resources')
        display_addons(get_addons, ['Plan', 'Name', 'Billed to', 'Price'])
      end

      def display_attachments(attachments, fields)
        if attachments.empty?
          display('There are no attachments.')
        else
          table = attachments.map do |attachment|
            {
              'Name'        => attachment['name'],
              'Add-on'      => attachment['addon']['name'],
              'Billing App' => attachment['addon']['app']['name'],
              'App'         => attachment['app']['name']
            }
          end.sort_by { |addon| fields.map { |f| addon[f] } }

          display_table(table, fields, fields)
        end
      end

      def display_addons(addons, fields)
        if addons.empty?
          display('There are no add-ons.')
        else
          table = addons.map do |addon|
            {
              'Plan'      => addon['plan']['name'],
              'Name'      => addon['name'],
              'Billed to' => addon['app']['name'],
              'Price'     => format_price(addon['plan']['price'])
            }
          end.sort_by { |addon| fields.map { |f| addon[f] } }

          display_table(table, fields, fields)
        end
      end

      def format_price(price)
        if price['cents'] == 0
          'free'
        else
          '$%.2f/%s' % [(price['cents'] / 100.0), price['unit']]
        end
      end
    end
  end
end
