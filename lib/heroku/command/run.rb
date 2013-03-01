require "readline"
require "heroku/command/base"
require "heroku/helpers/log_displayer"

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
  # -t, --tail           # stream logs for the process
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
    if options[:tail]
      opts = []
      opts << "tail=1"
      opts << "ps=#{process_data['process']}"
      log_displayer = ::Heroku::Helpers::LogDisplayer.new(heroku, app, opts)
      log_displayer.display_logs
    else
      display("Use `heroku logs -p #{process_data['process']}` to view the output.")
    end
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
    deprecate("`heroku #{current_command}` has been deprecated. Please use `heroku run console` instead.")
    command = "console #{args.join(' ')}"
    run_attached(command)
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
end
