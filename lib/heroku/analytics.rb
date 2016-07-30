require 'heroku/auth'

class Heroku::Analytics
  extend Heroku::Helpers

  def self.record(command)
    return if skip_analytics
    file = json_decode(File.read(path)) || new_file rescue new_file
    c = Heroku::Command.parse(command)
    return if c && c[:js]
    file["commands"] ||= []
    file["commands"] << {
      command:       command,
      timestamp:     Time.now.to_i,
      version:       Heroku::VERSION,
      os:            Heroku::JSPlugin.os,
      arch:          Heroku::JSPlugin.arch,
      language:      "ruby",
      valid:         !!c,
      plugin:        c[:plugin],
    }
    File.open(path, 'w') { |f| f.write(json_encode(file)) }
  rescue
  end

  private

  def self.skip_analytics
    return true if ['1', 'true'].include?(ENV['HEROKU_SKIP_ANALYTICS'])
    return true if ENV['CODESHIP'] == 'true'
    return true if ARGV.include? "--help"
    return true if ARGV.include? "-h"
    return true unless user

    if Heroku::Config[:skip_analytics] == nil
      stderr_puts "Heroku CLI submits usage information back to Heroku. If you would like to disable this, set `skip_analytics: true` in #{Heroku::Config.path}"
      Heroku::Config[:skip_analytics] = false
      Heroku::Config.save!
    end

    Heroku::Config[:skip_analytics]
  end

  def self.path
    home = Heroku::Helpers.home_directory
    cache = Heroku::Helpers::Env['XDG_CACHE_HOME']
    cache ||= File.join(Heroku::Helpers::Env['LOCALAPPDATA'], 'heroku') if Heroku::JSPlugin.windows?
    cache ||= File.join(home, '.cache', 'heroku')
    File.join(cache, "analytics.json")
  end

  def self.user
    credentials = Heroku::Auth.read_credentials
    return unless credentials
    credentials[0] == '' ? nil : credentials[0]
  end

  def self.new_file
    {schema: 1}
  end
end
