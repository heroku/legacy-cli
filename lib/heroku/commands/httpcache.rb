module Heroku::Command
  class Httpcache < BaseWithApp
    def purge
      heroku.httpcache_purge(app)
      display "HTTP cache purged."
    end
  end
end
