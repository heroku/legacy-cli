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
  # $ heroku git:clone -a myapp
  # Cloning into 'myapp'...
  # Git remote heroku added
  #
  def clone
    git_options = args.join(" ")
    remote = options[:remote] || 'heroku'

    app_data = api.get_app(app).body

    display git("clone #{app_data['git_url']} #{git_options}")

    unless $?.exitstatus > 0 || options[:no_remote].is_a?(FalseClass)
      FileUtils.chdir(app_data['name']) do
        create_git_remote(remote, app_data['git_url'])
      end
    end
  end

  # git:remote [OPTIONS]
  #
  # adds a git remote to an app repo
  #
  # if OPTIONS are specified they will be passed to git remote add
  #
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  #
  #Examples:
  #
  # $ heroku git:remote -a myapp
  # Git remote heroku added
  #
  # $ heroku git:remote -a myapp
  # !    Git remote heroku already exists
  #
  def remote
    git_options = args.join(" ")
    remote = options[:remote] || 'heroku'

    if git('remote').split("\n").include?(remote)
      error("Git remote #{remote} already exists")
    else
      app_data = api.get_app(app).body
      create_git_remote(remote, app_data['git_url'])
    end
  end

end
