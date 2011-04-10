begin
  require "octotest"
rescue LoadError
  puts "missing the 'octotest' gem"
  exit 1
end

Autotest.add_discovery { "octotest" }
Autotest.add_discovery { "rspec" }

ENV["OCTOTEST_RUBIES"] = "ruby-1.8.7@heroku-gem ruby-1.9.2@heroku-gem"
