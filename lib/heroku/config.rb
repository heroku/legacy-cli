class Heroku::Config
  extend Heroku::Helpers

  def self.[](key)
    config[key.to_s]
  end

  def self.[]=(key, value)
    config[key.to_s] = value
  end

  def self.save!
    File.open(path, 'w') do |f|
      f.puts(JSON.pretty_generate(config))
    end
  end

  private

  def self.config
    FileUtils.mkdir_p File.dirname(path)
    @config ||= JSON.parse(File.read(path)) rescue {}
  end

  def self.path
    home = Heroku::Helpers.home_directory
    config = Heroku::Helpers::Env['XDG_CONFIG_HOME']
    config ||= File.join(Heroku::Helpers::Env['LOCALAPPDATA'], 'heroku') if Heroku::JSPlugin.windows?
    config ||= File.join(home, '.config', 'heroku')
    File.join(config, "config.json")
  end
end
