require "heroku/command/base"

# check status of heroku platform
#
class Heroku::Command::Status < Heroku::Command::Base

  # status
  #
  # display current status of heroku platform
  #
  #Example:
  #
  # $ heroku status
  # === Heroku Status
  # Development: No known issues at this time.
  # Production:  No known issues at this time.
  #
  def index
    validate_arguments!

    heroku_status_host = ENV['HEROKU_STATUS_HOST'] || "status.heroku.com"
    require('excon')
    status = json_decode(Excon.get("https://#{heroku_status_host}/api/v3/current-status.json", :nonblock => false).body)

    styled_header("Heroku Status")

    status['status'].each do |key, value|
      if value == 'green'
        status['status'][key] = 'No known issues at this time.'
      end
    end
    styled_hash(status['status'])

    unless status['issues'].empty?
      display
      status['issues'].each do |issue|
        duration = time_ago(issue['created_at']).gsub(' ago', '+')
        styled_header("#{issue['title']}  #{duration}")
        changes = issue['updates'].map do |issue|
          [
            time_ago(issue['created_at']),
            issue['update_type'],
            issue['contents']
          ]
        end
        styled_array(changes, :sort => false)
      end
    end
  end

end
