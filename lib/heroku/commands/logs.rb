module Heroku::Command
  class Logs < BaseWithApp
    def index
      display heroku.logs(app)
    end

    def cron
      display heroku.cron_logs(app)
    end
  end
end