module Salesforce::Command
  class Maintenance < BaseWithApp
    def on
      salesforce.maintenance(app, :on)
      display "Maintenance mode enabled."
    end

    def off
      salesforce.maintenance(app, :off)
      display "Maintenance mode disabled."
    end
  end
end
