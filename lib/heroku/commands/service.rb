module Heroku::Command
  class Service < Base
    def start
      error "heroku service:start is defunct.  Use heroku workers +1 instead."
    end

    def up
      error "heroku service:up is defunct.  Use heroku workers +1 instead."
    end

    def down
      error "heroku service:down is defunct.  Use heroku workers -1 instead."
    end

    def bounce
      error "heroku service:bounce is defunct.  Use heroku restart instead."
    end

    def status
      error "heroku service:status is defunct.  Use heroku ps instead."
    end
  end
end
