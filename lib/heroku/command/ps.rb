require "heroku/command/base"

# manage dynos (dynos, workers)
#
class Heroku::Command::Ps < Heroku::Command::Base
  PROCESS_TIERS =[
    {"tier"=>"free",         "max_scale"=>1,    "max_processes"=>2,    "cost"=>{"Free"=>0}},
    {"tier"=>"hobby",        "max_scale"=>1,    "max_processes"=>nil,  "cost"=>{"Hobby"=>700}},
    {"tier"=>"production",   "max_scale"=>100,  "max_processes"=>nil,  "cost"=>{"Standard-1X"=>2500,  "Standard-2X"=>5000,  "Performance"=>50000}},
    {"tier"=>"traditional",  "max_scale"=>100,  "max_processes"=>nil,  "cost"=>{"1X"=>3600,           "2X"=>7200,           "PX"=>57600}}
  ]

  costs = PROCESS_TIERS.collect do |tier|
    tier["cost"].collect do |name, cents_per_month|
      [name, (cents_per_month / 100)]
    end
  end
  COSTS = Hash[*costs.flatten]

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
    requires_preauth
    change_map = {}

    changes = args.map do |arg|
      if change = arg.scan(/^([a-zA-Z0-9_]+)([=+-]\d+)(?::([\w-]+))?$/).first
        formation, quantity, size = change
        quantity = quantity[1..-1].to_i if quantity[0] == "="
        change_map[formation] = [quantity, size]
        { "process" => formation, "quantity" => quantity, "size" => size}
      end
    end.compact

    if changes.empty?
      error("Usage: heroku ps:scale DYNO1=AMOUNT1[:SIZE] [DYNO2=AMOUNT2 ...]\nMust specify DYNO and AMOUNT to scale.\nDYNO must be alphanumeric.")
    end

    action("Scaling dynos") do
      change_tier_if_needed(edge_app_formation.body, changes)

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

  # ps:type [TYPE | DYNO=TYPE [DYNO=TYPE ...]]
  #
  # manage dyno types
  #
  # called with no arguments shows the current dyno type
  #
  # called with one argument sets the type
  # where type is one of traditional|free|hobby|standard-1x|standard-2x|performance
  #
  # called with 1..n DYNO=TYPE arguments sets the type per dyno
  # this is only available when the app is on production and performance
  #
  def type
    if args.any?{|arg| arg =~ /=/}
      _original_resize
      return
    end

    app
    process_tier = shift_argument
    process_tier.downcase! if process_tier
    validate_arguments!

    if %w[standard-1x standard-2x performance].include?(process_tier)
      special_case_change_tier_and_resize(process_tier)
      return
    end

    # get or update app.process_tier
    app_resp = process_tier.nil? ? edge_app_info : change_dyno_type(process_tier)

    # get, calculate and display app process type costs
    formation_resp = edge_app_formation

    display_dyno_type_and_costs(app_resp, formation_resp)
  end

  alias_method :resize, :type
  alias_command "resize", "ps:type"

  private

  def change_dyno_type(process_tier)
    print "Changing dyno type... "

    app_resp = patch_tier(process_tier)

    if app_resp.status != 200
      puts "failed"
      error app_resp.body["message"] + " Please use `heroku ps:scale` to change process size and scale."
    end

    puts "done."

    return app_resp
  end

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

  def display_dyno_type_and_costs(app_resp, formation_resp)
    tier_info = PROCESS_TIERS.detect { |t| t["tier"] == app_resp.body["process_tier"] }

    formation = formation_resp.body.reject {|ps| ps['quantity'] < 1}

    annotated = formation.sort_by{|d| d['type']}.map do |dyno|
      cost = tier_info["cost"][dyno["size"]] * dyno["quantity"] / 100
      {
        'dyno'    => dyno['type'],
        'type'    => dyno['size'].rjust(4),
        'qty'     => dyno['quantity'].to_s.rjust(3),
        'cost/mo' => cost.to_s.rjust(7)
      }
    end

    if annotated.empty?
      puts "No dynos active.\nUse `heroku ps:scale` to scale up dynos."
    else
      display_table(annotated, annotated.first.keys, annotated.first.keys)
    end
  end

  def edge_app_info
    api.request(
      :expects => 200,
      :method  => :get,
      :path    => "/apps/#{app}",
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=edge",
        "Content-Type" => "application/json"
      }
    )
  end

  def edge_app_formation
    api.request(
      :expects => 200,
      :method  => :get,
      :path    => "/apps/#{app}/formation",
      :headers => {
        "Accept"       => "application/vnd.heroku+json; version=3",
        "Content-Type" => "application/json"
      }
    )
  end

  def change_tier_if_needed(formation, changes)
    # first find what tier(s) the user wants to move to
    # if there are multiple it will be caught later
    new_tiers = tiers_in_formation(changes)

    # no tier specified, so we don't need to change anything
    return if new_tiers.length == 0

    # we have an unknown tier
    # instead of validating in the CLI, just continue
    # the API will error if there is an issue
    return unless new_tiers.all?

    new_tier = new_tiers[0]
    current_tier = tiers_in_formation(formation).first

    # the formation has no tier
    # change the tier to the requested one
    return patch_tier(new_tier) unless current_tier

    # tiers in formation and ps:scale are the same
    # just continue
    return if new_tier == current_tier

    # is the user changing all the dyno types to the new tier?
    if consistent_tier_after_changes?(formation, changes)
      # all dyno types are changing to the new tier so we can change to it
      patch_tier(new_tier)
    else
      # some of the proposed changes are in a different tier than existing dyno types
      # this is not allowed
      from_type = formation[0]["size"]
      to_type   = changes[0]["size"]
      error("Cannot mix #{to_type} with #{from_type} dynos.\nTo change all dynos to #{to_type}, run `heroku ps:type #{to_type}`.")
    end
  end

  def tiers_in_formation(formation)
    tier_map = {
      "free"        => "free",
      "hobby"       => "hobby",
      "standard-1x" => "production",
      "standard-2x" => "production",
      "performance" => "production",
    }
    formation
      .select { |p| p["size"]}            # types with a size
      .select { |p| p["quantity"] > 0 }   # types that have active dynos
      .map    { |p| p["size"]}            # get the size of the type
      .map    { |s| tier_map[s.downcase]} # get the tier of the size
      .uniq
  end

  def consistent_tier_after_changes?(formation, changes)
    formation = pretend_changes_to_formation(formation, changes)
    tiers_in_formation(formation).length == 1
  end

  # return a new formation object with changes applied
  # in-memory only, does not hit API
  def pretend_changes_to_formation(formation, changes)
    formation = deep_clone(formation)
    changes.each do |change|
      ps = formation.find{|p| p["type"] == change["process"]}
      next unless ps
      ps["size"] = change["size"] if change["size"]
      q = change["quantity"]
      if q.is_a? Fixnum
        ps["quantity"] = q
      elsif q.start_with? '+'
        ps["quantity"] += q[1..-1].to_i
      elsif q.start_with? '-'
        ps["quantity"] -= q[1..-1].to_i
      end
    end
    formation
  end

  def special_case_change_tier_and_resize(type)
    patch_tier("production")
    override_args = edge_app_formation.body.map { |ps| "#{ps['type']}=#{type}" }
    _original_resize(override_args)
  end

  def _original_resize(override_args=nil)
    app
    change_map = {}

    changes = (override_args || args).map do |arg|
      if arg =~ /^([a-zA-Z0-9_]+)=([\w-]+)$/
        change_map[$1] = $2
        { "process" => $1, "size" => $2 }
      end
    end.compact

    if changes.empty?
      message = [
          "Usage: heroku dyno:type DYNO1=1X|2X|PX [DYNO2=1X|2X|PX ...]",
          "Must specify DYNO and TYPE to resize."
      ]
      error(message.join("\n"))
    end

    resp = nil
    action("Resizing and restarting the specified dynos") do
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
    end

    resp.body.select {|p| change_map.key?(p['type']) }.each do |p|
      size = p["size"]
      display "#{p["type"]} dynos now #{size} ($#{COSTS[size]}/month)"
    end
  end
end

%w[type restart scale stop].each do |cmd|
  Heroku::Command::Base.alias_command "dyno:#{cmd}", "ps:#{cmd}"
end

