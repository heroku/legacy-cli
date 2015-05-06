require "heroku/command/base"

# manage git for apps
#
class Heroku::Command::Git < Heroku::Command::Base

  # git:clone [DIRECTORY]
  #
  # clones a heroku app to your local machine at DIRECTORY (defaults to app name)
  #
  # -a, --app    APP     # the Heroku app to use
  # -r, --remote REMOTE  # the git remote to create, default "heroku"
  #     --ssh-git        # use SSH git protocol
  #     --http-git       # HIDDEN: Use HTTP git protocol
  #
  #
  #Examples:
  #
  # $ heroku git:clone -a example
  # Cloning into 'example'...
  # remote: Counting objects: 42, done.
  # ...
  #
  def clone
    Heroku::JSPlugin.install('heroku-git')
    Heroku::JSPlugin.run('git', 'clone', ARGV[1..-1])
  end

  alias_command "clone", "git:clone"

  # git:remote [OPTIONS]
  #
  # adds a git remote to an app repo
  #
  # if OPTIONS are specified they will be passed to git remote add
  #
  # -a, --app    APP           # the Heroku app to use
  # -r, --remote REMOTE        # the git remote to create, default "heroku"
  #     --ssh-git              # use SSH git protocol
  #     --http-git             # HIDDEN: Use HTTP git protocol
  #
  #Examples:
  #
  # $ heroku git:remote -a example
  # set git remote heroku to https://git.heroku.com/example.git
  #
  def remote
    Heroku::JSPlugin.install('heroku-git')
    Heroku::JSPlugin.run('git', 'remote', ARGV[1..-1])
  end
end
