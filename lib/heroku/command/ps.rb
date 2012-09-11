require "heroku/command/base"

# manage processes (dynos, workers)
#
class Heroku::Command::Ps < Heroku::Command::Base

  # ps:dynos [QTY]
  #
  # DEPRECATED: use `heroku ps:scale dynos=N`
  #
  # scale to QTY web processes
  #
  # if QTY is not specified, display the number of web processes currently running
  #
  #Example:
  #
  # $ heroku ps:dynos 3
  # Scaling dynos... done, now running 3
  #
  def dynos
    # deprecation notice added to v2.21.3 on 03/16/12
    display("~ `heroku ps:dynos QTY` has been deprecated and replaced with `heroku ps:scale dynos=QTY`")

    dynos = shift_argument
    validate_arguments!

    if dynos
      action("Scaling dynos") do
        new_dynos = api.put_dynos(app, dynos).body["dynos"]
        status("now running #{new_dynos}")
      end
    else
      app_data = api.get_app(app).body
      if app_data["stack"] == "cedar"
        raise(Heroku::Command::CommandFailed, "For Cedar apps, use `heroku ps`")
      else
        display("#{app} is running #{quantify("dyno", app_data["dynos"])}")
      end
    end
  end

  alias_command "dynos", "ps:dynos"

  # ps:workers [QTY]
  #
  # DEPRECATED: use `heroku ps:scale workers=N`
  #
  # scale to QTY background processes
  #
  # if QTY is not specified, display the number of background processes currently running
  #
  #Example:
  #
  # $ heroku ps:dynos 3
  # Scaling workers... done, now running 3
  #
  def workers
    # deprecation notice added to v2.21.3 on 03/16/12
    display("~ `heroku ps:workers QTY` has been deprecated and replaced with `heroku ps:scale workers=QTY`")

    workers = shift_argument
    validate_arguments!

    if workers
      action("Scaling workers") do
        new_workers = api.put_workers(app, workers).body["workers"]
        status("now running #{new_workers}")
      end
    else
      app_data = api.get_app(app).body
      if app_data["stack"] == "cedar"
        raise(Heroku::Command::CommandFailed, "For Cedar apps, use `heroku ps`")
      else
        display("#{app} is running #{quantify("worker", app_data["workers"])}")
      end
    end
  end

  alias_command "workers", "ps:workers"

  # ps
  #
  # list processes for an app
  #
  #Example:
  #
  # $ heroku ps
  # === run: one-off processes
  # run.1: up for 5m: `bash`
  #
  # === web: `bundle exec thin start -p $PORT`
  # web.1: created for 30s
  #
  def index
    validate_arguments!
    processes = api.get_ps(app).body

    processes_by_command = Hash.new {|hash,key| hash[key] = []}
    processes.each do |process|
      name    = process["process"].split(".").first
      elapsed = time_ago(Time.now - process['elapsed'])

      if name == "run"
        key  = "run: one-off processes"
        item = "%s: %s %s: `%s`" % [ process["process"], process["state"], elapsed, process["command"] ]
      else
        key  = "#{name}: `#{process["command"]}`"
        item = "%s: %s %s" % [ process["process"], process["state"], elapsed ]
      end

      processes_by_command[key] << item
    end

    processes_by_command.keys.each do |key|
      processes_by_command[key] = processes_by_command[key].sort do |x,y|
        x.match(/\.(\d+):/).captures.first.to_i <=> y.match(/\.(\d+):/).captures.first.to_i
      end
    end

    processes_by_command.keys.sort.each do |key|
      styled_header(key)
      styled_array(processes_by_command[key], :sort => false)
    end
  end

  # ps:restart [PROCESS]
  #
  # restart an app process
  #
  # if PROCESS is not specified, restarts all processes on the app
  #
  #Examples:
  #
  # $ heroku ps:restart web.1
  # Restarting web.1 process... done
  #
  # $ heroku ps:restart web
  # Restarting web processes... done
  #
  # $ heroku ps:restart
  # Restarting processes... done
  #
  def restart
    process = shift_argument
    validate_arguments!

    message, options = case process
    when NilClass
      ["Restarting processes", {}]
    when /.+\..+/
      ps = args.first
      ["Restarting #{ps} process", { :ps => ps }]
    else
      type = args.first
      ["Restarting #{type} processes", { :type => type }]
    end

    action(message) do
      api.post_ps_restart(app, options)
    end
  end

  alias_command "restart", "ps:restart"

  # ps:scale PROCESS1=AMOUNT1 [PROCESS2=AMOUNT2 ...]
  #
  # scale processes by the given amount
  #
  #Examples:
  #
  # $ heroku ps:scale web=3 worker+1
  # Scaling web processes... done, now running 3
  # Scaling worker processes... done, now running 1
  #
  def scale
    changes = {}
    args.each do |arg|
      if arg =~ /^([a-zA-Z0-9_]+)([=+-]\d+)$/
        changes[$1] = $2
      end
    end

    if changes.empty?
      error("Usage: heroku ps:scale PROCESS1=AMOUNT1 [PROCESS2=AMOUNT2 ...]\nMust specify PROCESS and AMOUNT to scale.")
    end

    changes.keys.sort.each do |process|
      amount = changes[process]
      action("Scaling #{process} processes") do
        amount.gsub!("=", "")
        new_qty = api.post_ps_scale(app, process, amount).body
        status("now running #{new_qty}")
      end
    end
  end

  alias_command "scale", "ps:scale"

  # ps:stop PROCESS
  #
  # stop an app process
  #
  # Examples:
  #
  # $ heroku stop run.3
  # Stopping run.3 process... done
  #
  # $ heroku stop run
  # Stopping run processes... done
  #
  def stop
    process = shift_argument
    validate_arguments!

    message, options = case process
    when NilClass
      error("Usage: heroku ps:stop PROCESS\nMust specify PROCESS to stop.")
    when /.+\..+/
      ps = args.first
      ["Stopping #{ps} process", { :ps => ps }]
    else
      type = args.first
      ["Stopping #{type} processes", { :type => type }]
    end

    action(message) do
      api.post_ps_stop(app, options)
    end
  end

  alias_command "stop", "ps:stop"
end
