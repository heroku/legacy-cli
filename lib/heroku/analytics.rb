class Heroku::Analytics
  extend Heroku::Helpers

  def self.record(command)
    return if skip_analytics
    File.open(path, 'a') do |f|
      f.write("#{command}|#{Time.now.to_i}\n")
    end
  rescue
  end

  def self.submit
    return if skip_analytics
    lines = File.read(path).split("\n")
    return if lines.count < 10 # only submit if we have 10 entries to send
    fork do
      commands = lines.map do |line|
        line = line.split('|')
        {command: line[0], timestamp: line[1].to_i}
      end
      payload = {
        user:     user,
        commands: commands
      }
      Excon.post('https://heroku-cli-analytics.herokuapp.com/record', body: JSON.dump(payload))
      File.truncate(path, 0)
    end
  rescue
  end

  private

  def self.skip_analytics
    return true if ['1', 'true'].include?(ENV['HEROKU_SKIP_ANALYTICS'])
    skip = Heroku::Config[:skip_analytics]
    if skip == nil
      # user has not specified whether or not they want to submit usage information
      # prompt them to ask, but if they wait more than 20 seconds just assume they
      # want to skip analytics
      require 'timeout'
      stderr_print "Would you like to submit Heroku CLI usage information to better improve the CLI user experience?\n[y/N] "
      input = begin
        Timeout::timeout(20) do
          ask.downcase
        end
      rescue
        stderr_puts 'n'
      end
      Heroku::Config[:skip_analytics] = !['y', 'yes'].include?(input)
      Heroku::Config.save!
    end

    skip
  end

  def self.path
    File.join(Heroku::Helpers.home_directory, ".heroku", "analytics")
  end

  def self.user
    credentials = Heroku::Auth.read_credentials
    credentials[0] if credentials
  end
end
