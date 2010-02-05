module Heroku::Command
  class Maintenance < BaseWithApp
    def on
      heroku.maintenance(app, :on)
      display "Maintenance mode enabled."
    end

    def off
      heroku.maintenance(app, :off)
      display "Maintenance mode disabled."
    end
  end
end
