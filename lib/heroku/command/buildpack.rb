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
        styled_header("#{app} Buildpack URL#{app_buildpacks.size > 1 ? 's' : ''}")
        display_buildpacks(app_buildpacks.map{|bp| bp["buildpack"]["url"]})
      end
    end

    # buildpack:set BUILDPACK_URL
    #
    # set new app buildpack
    #
    # -i, --index NUM      # the 1-based index of the URL in the list of URLs
    #
    #Example:
    #
    # $ heroku buildpack:set -i 1 https://github.com/heroku/heroku-buildpack-ruby
    #
    def set
      unless buildpack_url = shift_argument
        error("Usage: heroku buildpack:set BUILDPACK_URL.\nMust specify target buildpack URL.")
      end

      validate_arguments!
      index = (options[:index] || 1).to_i
      index -= 1

      app_buildpacks = api.get_app_buildpacks_v3(app)[:body]

      buildpack_urls = app_buildpacks.map do |buildpack|
        ordinal = buildpack["ordinal"].to_i
        if ordinal == index
          buildpack_url
        else
          buildpack["buildpack"]["url"]
        end
      end

      # default behavior if index is out of range, or list is previously empty
      # is to add buildpack to the list
      if index < 0 or app_buildpacks.size <= index
        buildpack_urls << buildpack_url
      end

      api.put_app_buildpacks_v3(app, {:updates => buildpack_urls.map{|url| {:buildpack => url} }})
      if (buildpack_urls.size > 1)
        display "Buildpack set. Next release on #{app} will use:"
        display_buildpacks(buildpack_urls)
      else
        display "Buildpack set. Next release on #{app} will use #{buildpack_url}."
      end
      display "Run `git push heroku master` to create a new release using #{buildpack_url}."
    end

    # buildpack:clear
    #
    # clear all buildpacks set on the app
    #
    def clear
      api.put_app_buildpacks_v3(app, {:updates => []})

      vars = api.get_config_vars(app).body
      if vars.has_key?("BUILDPACK_URL")
        display "Buildpack(s) cleared."
        warn "WARNING: The BUILDPACK_URL config var is still set and will be used for the next release"
      elsif vars.has_key?("LANGUAGE_PACK_URL")
        display "Buildpack(s) cleared."
        warn "WARNING: The LANGUAGE_PACK_URL config var is still set and will be used for the next release"
      else
        display "Buildpack(s) cleared. Next release on #{app} will detect buildpack normally."
      end
    end

    private

    def display_buildpacks(buildpacks)
      if (buildpacks.size == 1)
        display("  #{buildpacks.first}")
      else
        buildpacks.each_with_index do |bp, i|
          display("  #{i+1}. #{bp}")
        end
      end
    end

  end
end
