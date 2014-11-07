require "heroku/command/base"

module Heroku::Command

  # manage plugins to the heroku gem
  class Plugins < Base

    # plugins
    #
    # list installed plugins
    #
    #Example:
    #
    # $ heroku plugins
    # === Installed Plugins
    # heroku-accounts
    #
    def index
      validate_arguments!

      plugins = ::Heroku::JSPlugin.plugins.map { |p| "#{p[:name]}@#{p[:version]}" }
      plugins.concat(::Heroku::Plugin.list)

      if plugins.length > 0
        styled_header("Installed Plugins")
        styled_array(plugins)
      else
        display("You have no installed plugins.")
      end
    end

    # plugins:install URL
    #
    # install a plugin
    #
    #Example:
    #
    # $ heroku plugins:install https://github.com/ddollar/heroku-accounts.git
    # Installing heroku-accounts... done
    #
    def install
      name = shift_argument
      validate_arguments!
      if name =~ /\./
        # if it contains a '.' then we are assuming it is a URL
        # and we should install it as a ruby plugin
        ruby_plugin_install(name)
      else
        js_plugin_install(name)
      end
    end

    # plugins:uninstall PLUGIN
    #
    # uninstall a plugin
    #
    #Example:
    #
    # $ heroku plugins:uninstall heroku-accounts
    # Uninstalling heroku-accounts... done
    #
    def uninstall
      plugin = Heroku::Plugin.new(shift_argument)
      validate_arguments!

      action("Uninstalling #{plugin.name}") do
        plugin.uninstall
      end
    end

    # plugins:update [PLUGIN]
    #
    # updates all plugins or a single plugin by name
    #
    #Example:
    #
    # $ heroku plugins:update
    # Updating heroku-accounts... done
    #
    # $ heroku plugins:update heroku-accounts
    # Updating heroku-accounts... done
    #
    def update
      plugins = if plugin = shift_argument
        [plugin]
      else
        ::Heroku::Plugin.list
      end
      validate_arguments!

      plugins.each do |plugin|
        begin
          action("Updating #{plugin}") do
            begin
              Heroku::Plugin.new(plugin).update
            rescue Heroku::Plugin::ErrorUpdatingSymlinkPlugin
              status "skipped symlink"
            end
          end
        rescue SystemExit
          # ignore so that other plugins still update
        end
      end
    end

    private

    def js_plugin_install(name)
      Heroku::JSPlugin.setup
      Heroku::JSPlugin.install(name)
    end

    def ruby_plugin_install(name)
      action("Installing #{name}") do
        plugin = Heroku::Plugin.new(name)
        if plugin.install
          unless Heroku::Plugin.load_plugin(plugin.name)
            plugin.uninstall
            exit(1)
          end
        else
          error("Could not install #{plugin.name}. Please check the URL and try again.")
        end
      end
    end
  end
end
