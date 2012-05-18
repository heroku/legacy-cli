require "heroku/command/base"

# check status of Heroku platform
#
class Heroku::Command::Status < Heroku::Command::Base



  # status
  #
  # display current status of Heroku platform
  #
  def index
    heroku_status_host = ENV['HEROKU_STATUS_HOST'] || "status.heroku.com"
    status = json_decode(heroku.get("https://#{heroku_status_host}/status.json"))

    display('')
    if status.values.all? {|value| value == 'green'}
      display("No known issues at this time.")
    else
      status.each do |key, value|
        display("#{key}: #{value}")
      end
      response = heroku.xml(heroku.get("https://#{heroku_status_host}/feed"))
      entry = response.elements.to_a("//entry").first
      display('')
      display(entry.elements['title'].text)
      display(entry.elements['content'].text.gsub(/\n\n/, "\n  ").gsub(/<[^>]*>/, ''))
    end
    display('')

  end

end
