require "readline"
require "heroku/command/base"

# run one-off commands (console, rake)
#
class Heroku::Command::Run < Heroku::Command::Base

  # run COMMAND
  #
  # run an attached process
  #
  #Example:
  #
  # $ heroku run bash
  # Running `bash` attached to terminal... up, run.1
  # ~ $
  #
  def index
    command = args.join(" ")
    error("Usage: heroku run COMMAND") if command.empty?
    run_attached(command)
  end

  # run:detached COMMAND
  #
  # run a detached process, where output is sent to your logs
  #
  #Example:
  #
  # $ heroku run:detached ls
  # Running `ls` detached... up, run.1
  # Use `heroku logs -p run.1` to view the output.
  #
  def detached
    command = args.join(" ")
    error("Usage: heroku run COMMAND") if command.empty?
    opts = { :attach => false, :command => command }
    app_name = app
    process_data = action("Running `#{command}` detached", :success => "up") do
      process_data = api.post_ps(app_name, command, { :attach => false }).body
      status(process_data['process'])
      process_data
    end
    display("Use `heroku logs -p #{process_data['process']}` to view the output.")
  end

  # run:rake COMMAND
  #
  # WARNING: `heroku run:rake` has been deprecated. Please use `heroku run rake` instead."
  #
  # remotely execute a rake command
  #
  #Example:
  #
  # $ heroku run:rake -T
  # Running `rake -T` attached to terminal... up, run.1
  # (in /app)
  # rake test  # run tests
  #
  def rake
    deprecate("`heroku #{current_command}` has been deprecated. Please use `heroku run rake` instead.")
    command = "rake #{args.join(' ')}"
    run_attached(command)
  end

  alias_command "rake", "run:rake"

  # run:console [COMMAND]
  #
  # open a remote console session
  #
  # if COMMAND is specified, run the command and exit
  #
  # NOTE: For Cedar apps, use `heroku run console`
  #
  #Examples:
  #
  # $ heroku console
  # Ruby console for example.heroku.com
  # >>
  #
  def console
    cmd = args.join(' ').strip
    if cmd.empty?
      console_session(app)
    else
      display(heroku.console(app, cmd))
    end
  rescue RestClient::RequestFailed => e
    if e.http_body =~ /For Cedar apps, use: `heroku run console`/
      deprecate("`heroku #{current_command}` has been deprecated for Cedar apps. Please use: `heroku run console` instead.")
      command = "console #{args.join(' ')}"
      run_attached(command)
    else
      raise(e)
    end
  rescue RestClient::RequestTimeout
    error("Timed out. Long running requests are not supported on the console.\nPlease consider creating a rake task instead.")
  rescue Heroku::Client::AppCrashed => e
    error(e.message)
  end

  alias_command "console", "run:console"

protected

  def run_attached(command)
    app_name = app
    process_data = action("Running `#{command}` attached to terminal", :success => "up") do
      process_data = api.post_ps(app_name, command, { :attach => true, :ps_env => get_terminal_environment }).body
      status(process_data["process"])
      process_data
    end
    rendezvous_session(process_data["rendezvous_url"])
  end

  def rendezvous_session(rendezvous_url, &on_connect)
    begin
      set_buffer(false)
      rendezvous = Heroku::Client::Rendezvous.new(
        :rendezvous_url => rendezvous_url,
        :connect_timeout => (ENV["HEROKU_CONNECT_TIMEOUT"] || 120).to_i,
        :activity_timeout => nil,
        :input => $stdin,
        :output => $stdout)
      rendezvous.on_connect(&on_connect)
      rendezvous.start
    rescue Timeout::Error
      error "\nTimeout awaiting process"
    rescue OpenSSL::SSL::SSLError
      error "Authentication error"
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      error "\nError connecting to process"
    rescue Interrupt
    ensure
      set_buffer(true)
    end
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
end
