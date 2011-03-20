require "active_support"
require "active_support/json"
require "active_support/ordered_hash"

# for compatibility with activesupport 2.2 and below
unless Kernel.const_defined?(:JSON)
  module JSON
    def self.parse(json)
      ActiveSupport::JSON.decode(json)
    end
  end
end

