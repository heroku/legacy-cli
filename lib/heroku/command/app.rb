require "heroku/command/base"

require 'readline'
require 'launchy'

module Heroku::Command
  class App < Base
    def self.namespace; nil; end

    # login
    #
    # log in with your heroku credentials
    #
    def login
      Heroku::Auth.login
    end

    # logout
    #
    # clear local authentication credentials
    #
    def logout
      Heroku::Auth.logout
      display "Local credentials cleared."
    end

    # list
    #
    # list your apps
    #
    def list
      list = heroku.list
      if list.size > 0
        display list.map {|name, owner|
          if heroku.user == owner
            name
          else
            "#{name.ljust(25)} #{owner}"
          end
        }.join("\n")
      else
        display "You have no apps."
      end
    end

    # create [NAME]
    #
    # create a new app
    #
    # -r, --remote # the git remote to create, default "heroku"
    # -s, --stack  # the stack on which to create the app
    #
    def create
      remote  = extract_option('--remote', 'heroku')
      stack   = extract_option('--stack', 'aspen-mri-1.8.6')
      timeout = extract_option('--timeout', 30).to_i
      addons  = (extract_option('--addons', '') || '').split(',')
      name    = args.shift.downcase.strip rescue nil
      name    = heroku.create_request(name, {:stack => stack})
      display("Creating #{name}...", false)
      begin
        Timeout::timeout(timeout) do
          loop do
            break if heroku.create_complete?(name)
            display(".", false)
            sleep 1
          end
        end
        display " done"

        addons.each do |addon|
          display "Adding #{addon} to #{name}... "
          heroku.install_addon(name, addon)
        end

        display app_urls(name)
      rescue Timeout::Error
        display "Timed Out! Check heroku info for status updates."
      end

      create_git_remote(name, remote || "heroku")
    end

    # rename NEWNAME
    #
    # rename the app
    #
    def rename
      name    = extract_app
      newname = args.shift.downcase.strip rescue ''
      raise(CommandFailed, "Invalid name.") if newname == ''

      heroku.update(name, :name => newname)
      display app_urls(newname)

      if remotes = git_remotes(Dir.pwd)
        remotes.each do |remote_name, remote_app|
          next if remote_app != name
          if has_git?
            git "remote rm #{remote_name}"
            git "remote add #{remote_name} git@#{heroku.host}:#{newname}.git"
            display "Git remote #{remote_name} updated"
          end
        end
      else
        display "Don't forget to update your Git remotes on any local checkouts."
      end
    end

    # info
    #
    # show detailed app information
    #
    def info
      name = (args.first && !args.first =~ /^\-\-/) ? args.first : extract_app
      attrs = heroku.info(name)

      attrs[:web_url] ||= "http://#{attrs[:name]}.#{heroku.host}/"
      attrs[:git_url] ||= "git@#{heroku.host}:#{attrs[:name]}.git"

      display "=== #{attrs[:name]}"
      display "Web URL:        #{attrs[:web_url]}"
      display "Domain name:    http://#{attrs[:domain_name]}/" if attrs[:domain_name]
      display "Git Repo:       #{attrs[:git_url]}"
      display "Dynos:          #{attrs[:dynos]}"
      display "Workers:        #{attrs[:workers]}"
      display "Repo size:      #{format_bytes(attrs[:repo_size])}" if attrs[:repo_size]
      display "Slug size:      #{format_bytes(attrs[:slug_size])}" if attrs[:slug_size]
      display "Stack:          #{attrs[:stack]}" if attrs[:stack]
      if attrs[:database_size]
        data = format_bytes(attrs[:database_size])
        if tables = attrs[:database_tables]
          data = data.gsub('(empty)', '0K') + " in #{quantify("table", tables)}"
        end
        display "Data size:      #{data}"
      end

      if attrs[:cron_next_run]
        display "Next cron:      #{format_date(attrs[:cron_next_run])} (scheduled)"
      end
      if attrs[:cron_finished_at]
        display "Last cron:      #{format_date(attrs[:cron_finished_at])} (finished)"
      end

      unless attrs[:addons].empty?
        display "Addons:         " + attrs[:addons].map { |a| a['description'] }.join(', ')
      end

      display "Owner:          #{attrs[:owner]}"
      collaborators = attrs[:collaborators].delete_if { |c| c[:email] == attrs[:owner] }
      unless collaborators.empty?
        first = true
        lead = "Collaborators:"
        attrs[:collaborators].each do |collaborator|
          display "#{first ? lead : ' ' * lead.length}  #{collaborator[:email]}"
          first = false
        end
      end

      if attrs[:create_status] != "complete"
        display "Create Status:  #{attrs[:create_status]}"
      end
    end

    # open
    #
    # open the app in a web browser
    #
    def open
      app = extract_app

      url = web_url(app)
      puts "Opening #{url}"
      Launchy.open url
    end

    # rake
    #
    # remotely execute a rake command
    #
    def rake
      app = extract_app
      cmd = args.join(' ')
      if cmd.length == 0
        display "Usage: heroku rake <command>"
      else
        heroku.start(app, "rake #{cmd}", :attached).each { |chunk| display(chunk, false) }
      end
    rescue Heroku::Client::AppCrashed => e
      error "Couldn't run rake\n#{e.message}"
    end

    # console [COMMAND]
    #
    # open a remote console session
    #
    # if COMMAND is specified, run the command and exit
    #
    def console
      app = extract_app
      cmd = args.join(' ').strip
      if cmd.empty?
        console_session(app)
      else
        display heroku.console(app, cmd)
      end
    rescue RestClient::RequestTimeout
      error "Timed out. Long running requests are not supported on the console.\nPlease consider creating a rake task instead."
    rescue Heroku::Client::AppCrashed => e
      error e.message
    end

    # restart
    #
    # restart app processes
    #
    def restart
      app_name = extract_app
      heroku.restart(app_name)
      display "App processes restarted"
    end

    # dynos [QTY]
    #
    # scale to QTY web processes
    #
    # if QTY is not specified, display the number of web processes currently running
    #
    def dynos
      app = extract_app
      if dynos = args.shift
        current = heroku.set_dynos(app, dynos)
        display "#{app} now running #{quantify("dyno", current)}"
      else
        info = heroku.info(app)
        display "#{app} is running #{quantify("dyno", info[:dynos])}"
      end
    end

    # workers [QTY]
    #
    # scale to QTY background processes
    #
    # if QTY is not specified, display the number of background processes currently running
    #
    def workers
      app = extract_app
      if workers = args.shift
        current = heroku.set_workers(app, workers)
        display "#{app} now running #{quantify("worker", current)}"
      else
        info = heroku.info(app)
        display "#{app} is running #{quantify("worker", info[:workers])}"
      end
    end

    # destroy
    #
    # permanently destroy an app
    #
    def destroy
      app = extract_app
      info = heroku.info(app)
      url  = info[:domain_name] || "http://#{info[:name]}.#{heroku.host}/"

      if confirm_command(app)
        redisplay "Destroying #{app} (including all add-ons)... "
        heroku.destroy(app)
        if remotes = git_remotes(Dir.pwd)
          remotes.each do |remote_name, remote_app|
            next if app != remote_app
            git "remote rm #{remote_name}"
          end
        end
        display "done"
      end
    end

    # ps
    #
    # list processes for an app
    #
    def ps
      app = extract_app
      ps = heroku.ps(app)

      output = []
      output << "Process       State               Command"
      output << "------------  ------------------  ------------------------------"

      ps.sort_by do |p|
        t,n = p['process'].split(".")
        [t, n.to_i]
      end.each do |p|
        output << "%-12s  %-18s  %s" %
          [ p['process'], "#{p['state']} for #{time_ago(p['elapsed']).gsub(/ ago/, '')}", truncate(p['command'], 36) ]
      end

      display output.join("\n")
    end

    protected
      @@kb = 1024
      @@mb = 1024 * @@kb
      @@gb = 1024 * @@mb
      def format_bytes(amount)
        amount = amount.to_i
        return '(empty)' if amount == 0
        return amount if amount < @@kb
        return "#{(amount / @@kb).round}k" if amount < @@mb
        return "#{(amount / @@mb).round}M" if amount < @@gb
        return "#{(amount / @@gb).round}G"
      end

      def quantify(string, num)
        "%d %s" % [ num, num.to_i == 1 ? string : "#{string}s" ]
      end

      def console_history_dir
        FileUtils.mkdir_p(path = "#{home_directory}/.heroku/console_history")
        path
      end

      def console_session(app)
        heroku.console(app) do |console|
          console_history_read(app)

          display "Ruby console for #{app}.#{heroku.host}"
          while cmd = Readline.readline('>> ')
            unless cmd.nil? || cmd.strip.empty?
              console_history_add(app, cmd)
              break if cmd.downcase.strip == 'exit'
              display console.run(cmd)
            end
          end
        end
      end

      def console_history_file(app)
        "#{console_history_dir}/#{app}"
      end

      def console_history_read(app)
        history = File.read(console_history_file(app)).split("\n")
        if history.size > 50
          history = history[(history.size - 51),(history.size - 1)]
          File.open(console_history_file(app), "w") { |f| f.puts history.join("\n") }
        end
        history.each { |cmd| Readline::HISTORY.push(cmd) }
      rescue Errno::ENOENT
      rescue Exception => ex
        display "Error reading your console history: #{ex.message}"
        if confirm("Would you like to clear it? (y/N):")
          FileUtils.rm(console_history_file(app)) rescue nil
        end
      end

      def console_history_add(app, cmd)
        Readline::HISTORY.push(cmd)
        File.open(console_history_file(app), "a") { |f| f.puts cmd + "\n" }
      end

      def create_git_remote(app, remote)
        return unless has_git?
        return if git('remote').split("\n").include?(remote)
        return unless File.exists?(".git")
        git "remote add #{remote} git@#{heroku.host}:#{app}.git"
        display "Git remote #{remote} added"
      end

      def app_urls(name)
        "http://#{name}.heroku.com/ | git@heroku.com:#{name}.git"
      end
  end
end
