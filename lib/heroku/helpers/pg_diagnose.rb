module Heroku::Helpers::PgDiagnose
  DIAGNOSE_URL = ENV.fetch('PGDIAGNOSE_URL', "https://pgdiagnose.herokuapp.com")
  private

  def run_diagnose(db_id)
    report = find_or_generate_report(db_id)

    puts "Report #{report["id"]} for #{report["app"]}::#{report["database"]}"
    puts "available for one month after creation on #{report["created_at"]}"
    puts

    c = report['checks']
    process_checks 'red',     c.select{|f| f['status'] == 'red'}
    process_checks 'yellow',  c.select{|f| f['status'] == 'yellow'}
    process_checks 'green',   c.select{|f| f['status'] == 'green'}
    process_checks 'unknown', c.reject{|f| %w(red yellow green).include?(f['status'])}
  end

  def find_or_generate_report(db_id)
    if db_id =~ /\A[a-z0-9\-]{36}\z/
      response = get_report(db_id)
    else
      response = generate_report(db_id)
    end

    JSON.parse(response.body)
  rescue Excon::Errors::Error => e
    message = Heroku::Command.extract_error(e.response.body) do
      "Unable to connect to PGDiagnose API, please try again later"
    end

    error(message)
  end

  def get_report(report_id)
    Excon.get("#{DIAGNOSE_URL}/reports/#{report_id}",
              :expects => [200, 201],
              :headers => {"Content-Type" => "application/json"})
  end

  def generate_report(db_id)
    attachment = generate_resolver.resolve(db_id, "DATABASE_URL")
    validate_arguments!

    warn_old_databases(attachment)

    metrics = get_metrics(attachment)

    params = {
      'url'  => attachment.url,
      'plan' => attachment.plan,
      'metrics' => metrics,
      'app'  => attachment.app,
      'database' => attachment.config_var
    }

    return Excon.post("#{DIAGNOSE_URL}/reports",
                      :expects => [200, 201],
                      :body => params.to_json,
                      :headers => {"Content-Type" => "application/json"})
  end

  def warn_old_databases(attachment)
    @uri = URI.parse(attachment.url) # for #nine_two?
    if !nine_two?
      warn "WARNING: pg:diagnose is only fully supported on Postgres version >= 9.2. Some checks will be skipped.\n\n"
    end
  end

  def get_metrics(attachment)
    unless attachment.starter_plan?
      hpg_client(attachment).metrics
    end
  end

  def color(message, status)
    if color?
      color_code = { "red" => 31, "green" => 32, "yellow" => 33 }.fetch(status, 35)
      return "\e[#{color_code}m#{message}\e[0m"
    else
      return message
    end
  end

  def color?
    $stdout.tty?
  end

  def process_checks(status, checks)
    return unless checks.size > 0

    checks.each do |check|
      status = check['status']
      puts color("#{status.upcase}: #{check['name']}", status)
      next if "green" == status

      results = check['results']
      return unless results && results.size > 0

      if results.first.kind_of? Array
        puts "  " + results.first.map(&:capitalize).join(" ")
      else
        display_table(
          results,
          results.first.keys,
          results.first.keys.map{ |field| field.split(/_/).map(&:capitalize).join(' ') }
        )
      end
      puts
    end
  end
end

