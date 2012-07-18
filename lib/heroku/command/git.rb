require "heroku/command/base"

# manage git for apps
#
class Heroku::Command::Git < Heroku::Command::Base

  # git:clone [OPTIONS]
  #
  # clones an app repo
  #
  # if OPTIONS are specified they will be passed to git clone
  #
  # -n, --no-remote            # don't create a git remote
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  #
  #Examples:
  #
  #
  def clone
    git_options = args.join(" ")

    app_data = api.get_app(app).body

    display git("clone #{app_data['git_url']} #{git_options}")

    unless options[:no_remote].is_a?(FalseClass)
      FileUtils.chdir(app_data['name']) do
        create_git_remote(options[:remote] || 'heroku', app_data['git_url'])
      end
    end
  end

end
