require "spec_helper"
require "heroku/command/regions"

module Heroku::Command
  describe Regions do

    before do
      # stub_core
      Excon.stub(
        :headers => { "Accept" => "application/vnd.heroku+json; version=3" },
        :method => :get,
        :path => "/regions") do
          {
            :body => '[
              {
                  "country":"Ireland",
                  "created_at":"2013-09-19T01:29:12Z",
                  "description":"Europe",
                  "id":"ed30241c-ed8c-4bb6-9714-61953675d0b4",
                  "locale":"Dublin",
                  "name":"eu",
                  "private_capable":false,
                  "provider":{
                    "name":"amazon-web-services",
                    "region":"eu-west-1"
                  },
                  "updated_at":"2015-08-20T01:37:59Z"
                },
                {
                  "country":"Japan",
                  "created_at":"2015-08-20T01:37:59Z",
                  "description":"Tokyo, Japan",
                  "id":"478864c7-3c1a-4fbd-992b-7c6160abfb71",
                  "locale":"Tokyo",
                  "name":"tokyo",
                  "private_capable":true,
                  "provider":{
                    "name":"amazon-web-services",
                    "region":"ap-northeast-1"
                  },
                  "updated_at":"2015-08-20T01:37:59Z"
                },
                {
                  "country":"United States",
                  "created_at":"2012-11-21T21:44:16Z",
                  "description":"United States",
                  "id":"59accabd-516d-4f0e-83e6-6e3757701145",
                  "locale":"Virginia",
                  "name":"us",
                  "private_capable":false,
                  "provider":{
                    "name":"amazon-web-services",
                    "region":"us-east-1"
                  },
                  "updated_at":"2015-08-20T01:37:59Z"
                }
            ]',
          }
      end
    end

    it "shows regions paritioned into runtimes" do
      stderr, stdout = execute("regions")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== Common Runtime
eu  Europe
us  United States

=== Private Spaces
tokyo  Tokyo, Japan

STDOUT
    end

  end
end
