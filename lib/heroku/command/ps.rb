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

  # ps:restart
  #
  # restart app processes
  #
  def restart
    app_name = extract_app
    heroku.restart(app_name)
    display "App processes restarted"
  end

  alias_command "restart", "ps:restart"

end

