module Heroku::Command
  class Version < Base
    def index
      display Heroku::Client.gem_version_string
    end
  end
end
