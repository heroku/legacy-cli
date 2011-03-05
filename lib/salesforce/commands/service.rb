module Salesforce::Command
  class Service < Base
    def start
      error "salesforce service:start is defunct.  Use salesforce workers +1 instead."
    end

    def up
      error "salesforce service:up is defunct.  Use salesforce workers +1 instead."
    end

    def down
      error "salesforce service:down is defunct.  Use salesforce workers -1 instead."
    end

    def bounce
      error "salesforce service:bounce is defunct.  Use salesforce restart instead."
    end

    def status
      error "salesforce service:status is defunct.  Use salesforce ps instead."
    end
  end
end
