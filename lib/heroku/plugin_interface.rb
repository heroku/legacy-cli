module Heroku::PluginInterface

  def self.included(base)
    base.extend Heroku::PluginInterface
  end

  def selected_application
    base_command.extract_app
  rescue Heroku::Command::CommandFailed
    nil
  end

  def applications
    @applications ||= (base_command.git_remotes(Dir.pwd) || []).inject({}) do |hash, (remote, app)|
      hash.update(app => remote)
    end
  end

  def command(command, *args)
    Heroku::Command.run_internal command.to_s, args
  end

  def base_command
    @base_command ||= Heroku::Command::Base.new(ARGV)
  end

end
