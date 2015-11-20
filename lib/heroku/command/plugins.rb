require "heroku/command/base"
require "heroku/jsplugin"

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
    # heroku-production-check@0.2.0
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
    # $ heroku plugins:install heroku-production-check
    # Installing heroku-production-check... done
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
    # $ heroku plugins:uninstall heroku-production-check
    # Uninstalling heroku-production-check... done
    #
    def uninstall
      plugin = Heroku::Plugin.new(shift_argument)
      validate_arguments!
      if Heroku::Plugin.list.include? plugin.name
        action("Uninstalling #{plugin.name}") do
          plugin.uninstall
        end
      else
        Heroku::JSPlugin.uninstall(plugin.name)
      end
    end

    # plugins:update [PLUGIN]
    #
    # updates all plugins or a single plugin by name
    #
    #Example:
    #
    # $ heroku plugins:update
    # Updating heroku-production-check... done
    #
    # $ heroku plugins:update heroku-production-check
    # Updating heroku-production-check... done
    #
    def update
      Heroku::JSPlugin.update
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

    # plugins:link [PATH]
    # Links a local plugin into CLI.
    # This is useful when developing plugins locally.
    # It simply symlinks the specified path into ~/.heroku/node_modules

    #Example:
    # $ heroku plugins:link .
    #
    def link
      Heroku::JSPlugin.setup
      Heroku::JSPlugin.run('plugins', 'link', ARGV[1..-1])
    end

    # HIDDEN: plugins:commands
    # Prints a table of commands and location
    def commands
      ruby_cmd = Heroku::Command.commands.inject({}) {|h, (cmd, _)| h[cmd] = {:type => 'ruby'} ; h}

      go_and_node_cmd = Heroku::JSPlugin.commands_info['commands'].inject({}) do |h, command| 
        cmd = command['command'] ? "#{command['topic']}:#{command['command']}" : command['topic']
        if command['plugin'] == ''
          h[cmd] = {:type => 'go'}
        else 
          h[cmd] = {:type => 'node', :plugin => command['plugin']}
        end
        h 
      end

      all_cmd = {}
      all_cmd.merge!(ruby_cmd)
      all_cmd.merge!(go_and_node_cmd)
      all_cmd.each {|(cmd_str, cmd)| cmd[:command] = cmd_str}

      sorted_cmd = all_cmd.sort { |a,b| a[0] <=> b[0] }

      display_table(sorted_cmd.map{|cmd| cmd[1]}, [:command, :type, :plugin], ["Command", "Type", "Plugin"])
      display("============")

      counts = all_cmd.inject(Hash.new(0)) {|h, (_, cmd)| h[cmd[:type]] += 1; h}
      counts.keys.sort.each {|type| display("% #{type}: #{(counts[type].to_f / all_cmd.size).round(2)}") }
    end

    private

    def js_plugin_install(name)
      Heroku::JSPlugin.install(name, force: true)
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
