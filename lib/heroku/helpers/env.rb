module Heroku
  module Helpers
    class Env
      def self.[](key)
        val = ENV[key]
    
        if val && Heroku::Helpers.running_on_windows? && val.encoding == Encoding::ASCII_8BIT
          val = val.dup.force_encoding('utf-8')
        end
    
        val
      end
    end
  end
end
