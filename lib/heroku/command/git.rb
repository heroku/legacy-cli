require "heroku/command/base"

# manage git for apps
#
class Heroku::Command::Git < Heroku::Command::Base

  # git:clone APP [DIRECTORY]
  #
  # clones a heroku app to your local machine at DIRECTORY (defaults to app name)
  #
  # -r, --remote REMOTE  # the git remote to create, default "heroku"
  #
  #Examples:
  #
  # $ heroku git:clone example
  # Cloning from app 'example'...
  # Cloning into 'example'...
  # remote: Counting objects: 42, done.
  # ...
  #
  def clone
    remote = options[:remote] || "heroku"

    name = options[:app] || shift_argument || error("Usage: heroku git:clone APP [DIRECTORY]")
    directory = shift_argument
    validate_arguments!

    git_url = api.get_app(name).body["git_url"]

    puts "Cloning from app '#{name}'..."
    system "git clone -o #{remote} #{git_url} #{directory}".strip
  end

  alias_command "clone", "git:clone"

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
  # $ heroku git:remote -a example
  # Git remote heroku added
  #
  # $ heroku git:remote -a example
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
