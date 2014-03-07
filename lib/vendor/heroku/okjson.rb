require 'multi_json'
module Heroku
  module OkJson
    extend self

    class Error < RuntimeError; end

    def decode(json)
      print_deprecation
      MultiJson.load(json)
    rescue MultiJson::LoadError
      raise Error
    end

    def encode(object)
      print_deprecation
      MultiJson.dump(object)
    end

    private

    def print_deprecation
      unless ENV['IGNORE_HEROKU_JSON_DEPRECATION'] == 'true'
        puts "WARNING: Heroku::OkJson is deprecated. Use MultiJson instead"
      end
    end
  end
end
