unless Kernel.const_defined?(:JSON)
  $:.unshift File.expand_path("../vendor/json_pure-1.5.1/lib", __FILE__)
  require "json/pure"
end

