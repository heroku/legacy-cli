require "heroku/command/base"
require "heroku/api/apps_v3"

module Heroku::Command

  # manage the buildpack for an app
  #
  class Buildpacks < Base

    # buildpacks
    #
    # display the buildpack_url(s) for an app
    #
    #Examples:
    #
    # $ heroku buildpacks
    # https://github.com/heroku/heroku-buildpack-ruby
    #
    def index
      validate_arguments!

      app_buildpacks = api.get_app_buildpacks_v3(app)[:body]

      if app_buildpacks.nil? or app_buildpacks.empty?
        display("#{app} has no Buildpack URL set.")
      else
        styled_header("#{app} Buildpack URL#{app_buildpacks.size > 1 ? 's' : ''}")
        display_buildpacks(app_buildpacks.map{|bp| bp["buildpack"]["url"]}, "")
      end
    end

    # buildpacks:set BUILDPACK_URL
    #
    # set new app buildpack, overwriting into list of buildpacks if neccessary
    #
    # -i, --index NUM      # the 1-based index of the URL in the list of URLs
    #
    #Example:
    #
    # $ heroku buildpacks:set -i 1 https://github.com/heroku/heroku-buildpack-ruby
    #
    def set
      unless buildpack_url = shift_argument
        error("Usage: heroku buildpacks:set BUILDPACK_URL.\nMust specify target buildpack URL.")
      end

      index = get_index(0)

      mutate_buildpacks_constructive(buildpack_url, index, "set") do |existing_url, ordinal|
        if ordinal == index
          buildpack_url
        else
          existing_url
        end
      end
    end

    # buildpacks:add BUILDPACK_URL
    #
    # add new app buildpack, inserting into list of buildpacks if neccessary
    #
    # -i, --index NUM      # the 1-based index of the URL in the list of URLs
    #
    #Example:
    #
    # $ heroku buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-ruby
    #
    def add
      unless buildpack_url = shift_argument
        error("Usage: heroku buildpacks:add BUILDPACK_URL.\nMust specify target buildpack URL.")
      end

      index = get_index

      mutate_buildpacks_constructive(buildpack_url, index, "added") do |existing_url, ordinal|
        if ordinal == index
          [buildpack_url, existing_url]
        else
          existing_url
        end
      end
    end

    # buildpacks:remove [BUILDPACK_URL]
    #
    # remove a buildpack set on the app
    #
    # -i, --index NUM      # the 1-based index of the URL to remove from the list of URLs
    #
    def remove
      if buildpack_url = shift_argument
        if options[:index]
          error("Please choose either index or Buildpack URL, but not both.")
        end
      elsif index = get_index
        # cool!
      else
        error("Usage: heroku buildpacks:remove [BUILDPACK_URL].\nMust specify a buildpack to remove, either by index or URL.")
      end

      mutate_buildpacks(buildpack_url, index, "removed") do |app_buildpacks|
        if app_buildpacks.size == 0
          error("No buildpacks were found. Next release on #{app} will detect buildpack normally.")
        end

        if index and (index < 0 or index > app_buildpacks.size)
          if app_buildpacks.size == 1
            error("Invalid index. Only valid value is 1.")
          else
            error("Invalid index. Please choose a value between 1 and #{app_buildpacks.size}")
          end
        end

        buildpack_urls = app_buildpacks.map { |buildpack|
          ordinal = buildpack["ordinal"].to_i
          if ordinal == index
            nil
          elsif buildpack["buildpack"]["url"] == buildpack_url
            nil
          else
            buildpack["buildpack"]["url"]
          end
        }.compact

        if buildpack_urls.size == app_buildpacks.size
          error("Buildpack not found. Nothing was removed.")
        end

        buildpack_urls
      end
    end

    # buildpacks:clear
    #
    # clear all buildpacks set on the app
    #
    def clear
      api.put_app_buildpacks_v3(app, {:updates => []})
      display_no_buildpacks("cleared", true)
    end

    private

    def mutate_buildpacks_constructive(buildpack_url, index, action)
      mutate_buildpacks(buildpack_url, index, action) do |app_buildpacks|
        buildpack_urls = app_buildpacks.map { |buildpack|
          ordinal = buildpack["ordinal"]
          existing_url = buildpack["buildpack"]["url"]
          if existing_url == buildpack_url
            error("The buildpack #{buildpack_url} is already set on your app.")
          else
            yield(existing_url, ordinal)
          end
        }.flatten.compact

        # default behavior if index is out of range, or list is previously empty
        # is to add buildpack to the list
        if app_buildpacks.empty? or index.nil? or app_buildpacks.size < index
          buildpack_urls << buildpack_url
        end

        buildpack_urls
      end
    end

    def mutate_buildpacks(buildpack_url, index, action)
      app_buildpacks = api.get_app_buildpacks_v3(app)[:body]

      buildpack_urls = yield(app_buildpacks)

      update_buildpacks(buildpack_urls, action)
    end

    def get_index(default=nil)
      validate_arguments!
      if options[:index]
        index = options[:index].to_i
        index -= 1
        if index < 0
          error("Invalid index. Must be greater than 0.")
        end
        index
      else
        default
      end
    end

    def update_buildpacks(buildpack_urls, action)
      api.put_app_buildpacks_v3(app, {:updates => buildpack_urls.map{|url| {:buildpack => url} }})
      display_buildpack_change(buildpack_urls, action)
    end

    def display_buildpacks(buildpacks, indent="  ")
      if (buildpacks.size == 1)
        display(buildpacks.first)
      else
        buildpacks.each_with_index do |bp, i|
          display("#{indent}#{i+1}. #{bp}")
        end
      end
    end

    def display_buildpack_change(buildpack_urls, action)
      if buildpack_urls.size > 1
        display "Buildpack #{action}. Next release on #{app} will use:"
        display_buildpacks(buildpack_urls)
        display "Run `git push heroku master` to create a new release using these buildpacks."
      elsif buildpack_urls.size == 1
        display "Buildpack #{action}. Next release on #{app} will use #{buildpack_urls.first}."
        display "Run `git push heroku master` to create a new release using this buildpack."
      else
        display_no_buildpacks
      end
    end

    def display_no_buildpacks(action="removed", plural=false)
      vars = api.get_config_vars(app).body
      if vars.has_key?("BUILDPACK_URL")
        display "Buildpack#{plural ? "s" : ""} #{action}."
        warn "WARNING: The BUILDPACK_URL config var is still set and will be used for the next release"
      elsif vars.has_key?("LANGUAGE_PACK_URL")
        display "Buildpack#{plural ? "s" : ""} #{action}."
        warn "WARNING: The LANGUAGE_PACK_URL config var is still set and will be used for the next release"
      else
        display "Buildpack#{plural ? "s" : ""} #{action}. Next release on #{app} will detect buildpack normally."
      end
    end

  end
end
