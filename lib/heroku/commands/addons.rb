module Heroku::Command
  class Addons < BaseWithApp
    def index
      installed = heroku.installed_addons(app)
      if installed.empty?
        display "No addons installed"
      else
        available, pending = installed.partition { |a| a['configured'] }

        available.map do |a|
          if a['attachment_name']
            a['name'] + ' => ' + a['attachment_name']
          else
            a['name']
          end
        end.sort.each do |addon|
          display(addon)
        end

        unless pending.empty?
          display "\n--- not configured ---"
          pending.map { |a| a['name'] }.sort.each do |addon|
            display addon.ljust(24) + "http://#{heroku.host}/myapps/#{app}/addons/#{addon}"
          end
        end
      end
    end

    def info
      addons = heroku.addons
      if addons.empty?
        display "No addons available currently"
      else
        available, beta = addons.partition { |a| !a['beta'] }
        display_addons(available)
        if !beta.empty?
          display "\n--- beta ---"
          display_addons(beta)
        end
      end
    end

    def add
      configure_addon('Adding') do |addon, config|
        heroku.install_addon(app, addon, config)
      end
    end

    def upgrade
      configure_addon('Upgrading') do |addon, config|
        heroku.upgrade_addon(app, addon, config)
      end
    end
    alias_method :downgrade, :upgrade

    def remove
      args.each do |name|
        display "Removing #{name} from #{app}... ", false
        display addon_run { heroku.uninstall_addon(app, name) }
      end
    end

    def clear
      heroku.installed_addons(app).each do |addon|
        next if addon['name'] =~ /^shared-database/
        display "Removing #{addon['description']} from #{app}... ", false
        display addon_run { heroku.uninstall_addon(app, addon['name']) }
      end
    end

    def open
      addon = args.shift
      app_addons = heroku.installed_addons(app).map { |a| a["name"] }
      matches = app_addons.select { |a| a =~ /^#{addon}/ }

      case matches.length
      when 0 then
        error "Unknown addon: #{addon}"
      when 1 then
        addon_to_open = matches.first
        display "Opening #{addon_to_open} for #{app}..."
        Launchy.open "https://api.#{heroku.host}/myapps/#{app}/addons/#{addon_to_open}"
      else
        error "Ambiguous addon name: #{addon}"
      end
    end

    def confirm_billing
      Heroku::Command.run_internal 'account:confirm_billing', []
    end

    private
      def display_addons(addons)
        grouped = addons.inject({}) do |base, addon|
          group, short = addon['name'].split(':')
          base[group] ||= []
          base[group] << addon.merge('short' => short)
          base
        end
        grouped.keys.sort.each do |name|
          addons = grouped[name]
          row = name.dup
          if addons.any? { |a| a['short'] }
            row << ':'
            size = row.size
            stop = false
            row << addons.map { |a| a['short'] }.sort.map do |short|
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
          display row.ljust(34) + (addons.first['url'] || '')
        end
      end

      def addon_run
        response = yield

        if response
          price = "(#{ response['price'] })" if response['price']
          message = response['message']
        end

        out = [ 'done', price ].compact.join(' ')
        if message
          out += "\n"
          out += message.split("\n").map do |line|
            "  #{line}"
          end.join("\n")
        end
        out
      rescue RestClient::ResourceNotFound => e
        "FAILED\n !   #{e.response.to_s}"
      rescue RestClient::RequestFailed => e
        retry if e.http_code == 402 && confirm_billing
        "FAILED\n" + Heroku::Command.extract_error(e.http_body)
      end

      def configure_addon(label, &install_or_upgrade)
        addon = args.shift
        raise CommandFailed.new("Missing add-on name") unless addon

        config = {}
        args.each do |arg|
          key, value = arg.strip.split('=', 2)
          if value.nil?
            error("Non-config value \"#{arg}\".\nEverything after the addon name should be a key=value pair")
          else
            config[key] = value
          end
        end

        display "#{label} #{addon} to #{app}... ", false
        display addon_run { install_or_upgrade.call(addon, config) }
      end
  end
end
