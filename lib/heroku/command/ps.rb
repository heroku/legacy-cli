require "heroku/command/base"
require "json"

# manage dynos (dynos, workers)
#
class Heroku::Command::Ps < Heroku::Command::Base
  PRICES = {
    "P"  => 0.8,
    "PX" => 0.8,
  }

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
  # list dynos for an app
  #
  #Example:
  #
  # $ heroku ps
  # === run: one-off dyno
  # run.1: up for 5m: `bash`
  #
  # === web: `bundle exec thin start -p $PORT`
  # web.1: created for 30s
  #
  def index
    validate_arguments!
    resp = api.request(
      :expects => 200,
      :method  => :get,
      :path    => "/apps/#{app}/dynos",
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=3",
        "Content-Type" => "application/json"
      }
    )
    processes = resp.body

    processes_by_command = Hash.new {|hash,key| hash[key] = []}
    processes.each do |process|
      now     = Time.now
      type    = process["type"]
      elapsed = now - Time.iso8601(process['updated_at'])
      since   = time_ago(now - elapsed)
      size    = process["size"] || "1X"

      if type == "run"
        key  = "run: one-off processes"
        item = "%s (%s): %s %s: `%s`" % [ process["name"], size, process["state"], since, process["command"] ]
      else
        key  = "#{type} (#{size}): `#{process["command"]}`"
        item = "%s: %s %s" % [ process['name'], process['state'], since ]
      end

      processes_by_command[key] << item
    end

    extract_run_id = /\.(\d+).*:/
    processes_by_command.keys.each do |key|
      processes_by_command[key] = processes_by_command[key].sort do |x,y|
        x.match(extract_run_id).captures.first.to_i <=> y.match(extract_run_id).captures.first.to_i
      end
    end

    processes_by_command.keys.sort.each do |key|
      styled_header(key)
      styled_array(processes_by_command[key], :sort => false)
    end
  end

  # ps:restart [DYNO]
  #
  # restart an app dyno
  #
  # if DYNO is not specified, restarts all dynos on the app
  #
  #Examples:
  #
  # $ heroku ps:restart web.1
  # Restarting web.1 dyno... done
  #
  # $ heroku ps:restart web
  # Restarting web dyno... done
  #
  # $ heroku ps:restart
  # Restarting dynos... done
  #
  def restart
    dyno = shift_argument
    validate_arguments!

    message, options = case dyno
    when NilClass
      ["Restarting dynos", {}]
    when /.+\..+/
      ps = args.first
      ["Restarting #{ps} dyno", { :ps => ps }]
    else
      type = args.first
      ["Restarting #{type} dynos", { :type => type }]
    end

    action(message) do
      api.post_ps_restart(app, options)
    end
  end

  alias_command "restart", "ps:restart"

  # ps:scale DYNO1=AMOUNT1 [DYNO2=AMOUNT2 ...]
  #
  # scale dynos by the given amount
  #
  # appending a size (eg. web=2:2X) allows simultaneous scaling and resizing
  #
  #Examples:
  #
  # $ heroku ps:scale web=3:2X worker+1
  # Scaling dynos... done, now running web at 3:2X, worker at 1:1X.
  #
  def scale
    change_map = {}

    changes = args.map do |arg|
      if change = arg.scan(/^([a-zA-Z0-9_]+)([=+-]\d+)(?::(\w+))?$/).first
        formation, quantity, size = change
        quantity.gsub!("=", "") # only allow + and - on quantity
        change_map[formation] = [quantity, size]
        {:process => formation, :quantity => quantity, :size => size}
      end
    end.compact

    if changes.empty?
      error("Usage: heroku ps:scale DYNO1=AMOUNT1[:SIZE] [DYNO2=AMOUNT2 ...]\nMust specify DYNO and AMOUNT to scale.")
    end

    action("Scaling dynos") do
      # The V3 API supports atomic scale+resize, so we make a raw request here
      # since the heroku-api gem still only supports V2.
      resp = api.request(
        :expects => 200,
        :method  => :patch,
        :path    => "/apps/#{app}/formation",
        :body    => {:updates => changes}.to_json,
        :headers => {
          "Accept"       => "application/vnd.heroku+json; version=3",
          "Content-Type" => "application/json"
        }
      )
      new_scales = resp.body.
        select {|p| change_map[p['type']] }.
        map {|p| "#{p["type"]} at #{p["quantity"]}:#{p["size"]}" }
      status("now running " + new_scales.join(", ") + ".")
    end
  end

  alias_command "scale", "ps:scale"

  # ps:stop DYNOS
  #
  # stop an app dyno
  #
  # Examples:
  #
  # $ heroku stop run.3
  # Stopping run.3 dyno... done
  #
  # $ heroku stop run
  # Stopping run dynos... done
  #
  def stop
    dyno = shift_argument
    validate_arguments!

    message, options = case dyno
    when NilClass
      error("Usage: heroku ps:stop DYNO\nMust specify DYNO to stop.")
    when /.+\..+/
      ps = args.first
      ["Stopping #{ps} dyno", { :ps => ps }]
    else
      type = args.first
      ["Stopping #{type} dynos", { :type => type }]
    end

    action(message) do
      api.post_ps_stop(app, options)
    end
  end

  alias_command "stop", "ps:stop"

  # ps:resize DYNO1=1X|2X|PX [DYNO2=1X|2X|PX ...]
  #
  # resize dynos to the given size
  #
  # Example:
  #
  # $ heroku ps:resize web=PX worker=2X
  # Resizing and restarting the specified dynos... done
  # web dynos now PX ($0.80/dyno-hour)
  # worker dynos now 2X ($0.10/dyno-hour)
  #
  def resize
    app
    change_map = {}

    changes = args.map do |arg|
      if arg =~ /^([a-zA-Z0-9_]+)=(\w+)$/
        change_map[$1] = $2
        { "process" => $1, "size" => $2 }
      end
    end.compact

    if changes.empty?
      message = [
          "Usage: heroku ps:resize DYNO1=1X|2X|PX [DYNO2=1X|2X|PX ...]",
          "Must specify DYNO and SIZE to resize."
      ]
      error(message.join("\n"))
    end

    resp = nil
    action("Resizing and restarting the specified dynos") do
      resp = api.request(
        :expects => 200,
        :method  => :patch,
        :path    => "/apps/#{app}/formation",
        :body    => { "updates" => changes }.to_json,
        :headers => {
          "Accept"       => "application/vnd.heroku+json; version=3",
          "Content-Type" => "application/json"
        }
      )
    end

    resp.body.select {|p| change_map.key?(p['type']) }.each do |p|
      size = p["size"]
      price = if size.to_i > 0
                sprintf("%.2f", 0.05 * size.to_i)
              else
                sprintf("%.2f", PRICES[size])
              end
      display "#{p["type"]} dynos now #{size} ($#{price}/dyno-hour)"
    end
  end

  alias_command "resize", "ps:resize"
end
