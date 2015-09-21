require "heroku/command/base"

# manage dynos (dynos, workers)
#
class Heroku::Command::Ps < Heroku::Command::Base
  COSTS = {"Free"=>0, "Hobby"=>7, "Standard-1X"=>25, "Standard-2X"=>50, "Performance-M"=>250, "Performance"=>500, "Performance-L"=>500, "1X"=>36, "2X"=>72, "PX"=>576}

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
    quota_resp = api.request(
      :expects => [200, 404],
      :method  => :post,
      :path    => "/apps/#{app}/actions/get-quota",
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=3.app-quotas",
        "Content-Type" => "application/json"
      }
    )

    if quota_resp.status = 200
      quota = quota_resp.body
      now = Time.now.getutc
      quota_message = if quota["allow_until"]
                        "Free quota left:"
                      elsif quota["deny_until"]
                        "Free quota exhausted. Unidle available in:"
                      end
      if quota_message
        quota_timestamp = (quota["allow_until"] ? Time.parse(quota["allow_until"]).getutc : Time.parse(quota["deny_until"]).getutc)
        time_left = time_remaining(Time.now.getutc, quota_timestamp)
        display("#{quota_message} #{time_left}")
      end
    end

    processes_resp = api.request(
      :expects => 200,
      :method  => :get,
      :path    => "/apps/#{app}/dynos",
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=3",
        "Content-Type" => "application/json"
      }
    )
    processes = processes_resp.body

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

  # ps:scale [DYNO1=AMOUNT1 [DYNO2=AMOUNT2 ...]]
  #
  # scale dynos by the given amount
  #
  # appending a size (eg. web=2:2X) allows simultaneous scaling and resizing
  #
  # omitting any arguments will display the app's current dyno formation, in a
  # format suitable for passing back into ps:scale
  #
  #Examples:
  #
  # $ heroku ps:scale web=3:2X worker+1
  # Scaling dynos... done, now running web at 3:2X, worker at 1:1X.
  #
  # $ heroku ps:scale
  # web=3:2X worker=1:1X
  #
  def scale
    requires_preauth

    changes = args.map do |arg|
      if change = arg.scan(/^([a-zA-Z0-9_]+)([=+-]\d+)(?::([\w-]+))?$/).first
        formation, quantity, size = change
        quantity = quantity[1..-1].to_i if quantity[0] == "="
        { "type" => formation, "quantity" => quantity, "size" => size}
      end
    end.compact

    if changes.empty?
      display_dyno_formation(get_formation)
    else
      action("Scaling dynos") do
        new_scales = scale_dynos(get_formation, changes)
                     .map {|p| "#{p["type"]} at #{p["quantity"]}:#{p["size"]}" }
        status("now running " + new_scales.join(", ") + ".")
      end
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

  # ps:type [TYPE | DYNO=TYPE [DYNO=TYPE ...]]
  #
  # manage dyno types
  #
  # called with no arguments shows the current dyno type
  #
  # called with one argument sets the type
  # where type is one of free|hobby|standard-1x|standard-2x|performance
  #
  # called with 1..n DYNO=TYPE arguments sets the type per dyno
  #
  def type
    requires_preauth
    app
    formation = get_formation
    changes = if args.any?{|arg| arg =~ /=/}
                args.map do |arg|
                  if arg =~ /^([a-zA-Z0-9_]+)=([\w-]+)$/
                    type, new_size = $1, $2
                    current_p = formation.find{|f| f["type"] == type}
                    if current_p.nil?
                      error("Type '#{type}' not found in process formation.")
                    end
                    p = current_p.clone
                    p["size"] = new_size
                    p
                  end
                end.compact
              elsif args.any?
                size = shift_argument.downcase
                validate_arguments!
                formation.map{|p| p["size"] = size; p}
              end
    scale_dynos(formation, changes) if changes
    display_dyno_type_and_costs(get_formation)
  end

  alias_method :resize, :type
  alias_command "resize", "ps:type"

  private

  def patch_tier(process_tier)
    api.request(
      :method  => :patch,
      :path    => "/apps/#{app}",
      :body    => json_encode("process_tier" => process_tier),
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=edge",
        "Content-Type" => "application/json"
      }
    )
  end

  def error_no_process_types
      error "No process types on #{app}.\nUpload a Procfile to add process types.\nhttps://devcenter.heroku.com/articles/procfile"
  end

  def display_dyno_type_and_costs(formation)
    annotated = formation.sort_by{|d| d['type']}.map do |dyno|
      cost = COSTS[dyno["size"]]
      {
        'dyno'    => dyno['type'],
        'type'    => dyno['size'].rjust(4),
        'qty'     => dyno['quantity'].to_s.rjust(3),
        'cost/mo' => cost ? (cost * dyno["quantity"]).to_s.rjust(7) : ''
      }
    end

    if annotated.empty?
      error_no_process_types
    else
      display_table(annotated, annotated.first.keys, annotated.first.keys)
    end
  end

  def display_dyno_formation(formation)
    dynos = formation.map{|d| "#{d['type']}=#{d['quantity']}:#{d['size']}"}.sort

    if dynos.empty?
      error_no_process_types
    else
      display dynos.join(" ")
    end
  end

  def get_formation
    api.request(
      :expects => 200,
      :method  => :get,
      :path    => "/apps/#{app}/formation",
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=3",
        "Content-Type" => "application/json"
      }
    ).body
  end

  def scale_dynos(formation, changes)
    # The V3 API supports atomic scale+resize, so we make a raw request here
    # since the heroku-api gem still only supports V2.
    resp = api.request(
      :expects => 200,
      :method  => :patch,
      :path    => "/apps/#{app}/formation",
      :body    => json_encode("updates" => changes),
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=3",
        "Content-Type" => "application/json"
      }
    )
    resp.body.select {|p| changes.any?{|c| c["type"] == p["type"]} }
  end
end

%w[type restart scale stop].each do |cmd|
  Heroku::Command::Base.alias_command "dyno:#{cmd}", "ps:#{cmd}"
end
