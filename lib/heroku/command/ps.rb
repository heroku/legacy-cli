require "heroku/command/base"

# manage processes (dynos, workers)
#
class Heroku::Command::Ps < Heroku::Command::Base

  # ps:dynos [QTY]
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

  alias_command "dynos", "ps:dynos"

  # ps:workers [QTY]
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

  alias_command "workers", "ps:workers"

  # ps
  #
  # list processes for an app
  #
  def index
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

  # ps:restart [PROCESS]
  #
  # restart an app process
  #
  # if PROCESS is not specified, restarts all processes on the app
  #
  def restart
    app = extract_app

    opts = case args.first
    when NilClass then
      display "Restarting processes... ", false
      {}
    when /.+\..+/
      ps = args.first
      display "Restarting #{ps} process... ", false
      { :ps => ps }
    else
      type = args.first
      display "Restarting #{type} processes... ", false
      { :type => type }
    end
    heroku.ps_restart(app, opts)
    display "done"
  end

  alias_command "restart", "ps:restart"

  # ps:scale PROCESS1=AMOUNT1 ...
  #
  # scale processes by the given amount
  #
  # Example: heroku scale web=3 worker+1
  #
  def scale
    app = extract_app
    current_process = nil
    args.inject({}) do |hash, process_amount|
      case process_amount
      when /^([a-z]+)([=+-]\d+)$/
        hash[$1] = $2
      when /^([a-z]+)$/
        current_process = $1
      when /^(\d+)$/
        if current_process
          hash[current_process] = $1
          current_process = nil
        end
      end
      hash
    end.each do |process, amount|
      display "Scaling #{process} processes... ", false
      amount.gsub!("=", "")
      new_qty = heroku.ps_scale(app, :type => process, :qty => amount)
      display "done, now running #{new_qty}"
    end
  end

  alias_command "scale", "ps:scale"

end

