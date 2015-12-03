require "heroku/command/base"
require "heroku/jsplugin"
require "csv"

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

      plugins = ::Heroku::JSPlugin.plugins.map { |p| "#{p[:name]}@#{p[:version]} #{p[:extra]}" }
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
    #
    # Prints a table of commands and location
    #
    #   -c, --csv  # Show with csv formatting
    def commands
      validate_arguments!

      ruby_cmd = Heroku::Command.commands.inject({}) {|h, (cmd, command)| h[cmd] = command_to_hash('ruby', cmd, command) ; h}
      commands = Heroku::JSPlugin.commands_info['commands']
      node_cmd = command_list_to_hash(commands.select {|command| command['plugin'] != ''}, 'node')
      go_cmd   = command_list_to_hash(commands.select {|command| command['plugin'] == ''}, 'go')

      all_cmd = {}
      all_cmd.merge!(ruby_cmd)
      all_cmd.merge!(node_cmd)
      all_cmd.merge!(go_cmd)

      sorted_cmd = all_cmd.sort { |a,b| a[0] <=> b[0] }.map{|cmd| cmd[1]}

      attrs  = [:command, :type, :plugin]
      header = attrs.map{|attr| attr.to_s.capitalize}

      count_attrs  = [:type, :count]
      count_header = count_attrs.map{|attr| attr.to_s.capitalize}

      counts = all_cmd.inject(Hash.new(0)) {|h, (_, cmd)| h[cmd[:type]] += 1; h}
      type_and_percentage = counts.keys.sort.map{|type| {:type => type, :count => counts[type]}}

      if options[:csv]
        csv_str = CSV.generate do |csv| 
          csv << header
          sorted_cmd.each {|cmd| csv << attrs.map{|attr| cmd[attr]}}

          csv << []
          csv << count_header
          type_and_percentage.each {|type| csv << count_attrs.map{|attr| type[attr]}}
        end
        display(csv_str)
      else
        display_table(sorted_cmd, attrs, header)
        display("")
        display_table(type_and_percentage, count_attrs, count_header)
      end
    end

    private

    def command_to_hash(type, cmd, command)
      command_hash = {:type => type, :command => cmd}
      command_hash[:plugin] = command['plugin'] if command['plugin'] && command['plugin'] != ''
      command_hash
    end

    def command_list_to_hash(commands, type)
      commands.inject({}) do |h, command| 
        cmd = command['command'] ? "#{command['topic']}:#{command['command']}" : command['topic']
        h[cmd] = command_to_hash(type, cmd, command)
        if command['default']
          cmd = command['topic']
          h[cmd] = command_to_hash(type, cmd, command)
        end
        h
      end
    end

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
