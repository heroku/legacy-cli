require "heroku/command/base"
require "heroku/api/apps_v3"

module Heroku::Command

  # manage the buildpack for an app
  #
  class Buildpack < Base

    # buildpack
    #
    # display the buildpack_url for an app
    #
    #Examples:
    #
    # $ heroku buildpack
    # https://github.com/heroku/heroku-buildpack-ruby
    #
    def index
      validate_arguments!

      app_buildpacks = api.get_app_buildpacks_v3(app)[:body]

      if app_buildpacks.nil? or app_buildpacks.empty?
        display("#{app} has no Buildpack URL set.")
      else
        styled_header("#{app} Buildpack URL")
        display(app_buildpacks.first["buildpack"]["url"])
      end
    end

    # buildpack:set BUILDPACK_URL
    #
    # set new app buildpack
    #
    def set
      unless buildpack_url = shift_argument
        error("Usage: heroku buildpack:set BUILDPACK_URL.\nMust specify target buildpack URL.")
      end

      api.put_app_buildpacks_v3(app, {:updates => [{:buildpack => buildpack_url}]})
      display "Buildpack set. Next release on #{app} will use #{buildpack_url}."
      display "Run `git push heroku master` to create a new release on #{buildpack_url}."
    end

    # buildpack:unset
    #
    # unset the app buildpack
    #
    def unset
      api.put_app_buildpacks_v3(app, {:updates => []})
      display "Buildpack unset. Next release on #{app} will detect buildpack normally."
    end

  end
end
