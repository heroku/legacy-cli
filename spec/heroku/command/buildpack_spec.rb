require "spec_helper"
require "heroku/command/buildpack"

module Heroku::Command
  describe Buildpack do

    def stub_put(*buildpacks)
      Excon.stub({
        :method => :put,
        :path => "/apps/example/buildpack-installations",
        :body => {"updates" => buildpacks.map{|bp| {"buildpack" => bp}}}.to_json
      },
      {:status => 200})
    end

    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar-14")

      Excon.stub({:method => :put, :path => "/apps/example/buildpack-installations"},
        {:status => 200})
      Excon.stub({:method => :get, :path => "/apps/example/buildpack-installations"},
        {
          :body => [{"buildpack" => { "url" => "https://github.com/heroku/heroku-buildpack-ruby"}}],
          :status => 200
        })
    end

    after(:each) do
      Excon.stubs.shift
      Excon.stubs.shift
      api.delete_app("example")
    end

    describe "index" do
      it "displays the buildpack URL" do
        stderr, stdout = execute("buildpack")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== example Buildpack URL
https://github.com/heroku/heroku-buildpack-ruby
        STDOUT
      end

      context "with no buildpack URL set" do
        before(:each) do
          Excon.stubs.shift
          Excon.stub({:method => :get, :path => "/apps/example/buildpack-installations"},
            {
            :body => [],
            :status => 200
            })
        end

        it "does not display a buildpack URL" do
          stderr, stdout = execute("buildpack")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
example has no Buildpack URL set.
          STDOUT
        end
      end
    end

    describe "set" do
      it "sets the buildpack URL" do
        stderr, stdout = execute("buildpack:set https://github.com/heroku/heroku-buildpack-ruby")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using https://github.com/heroku/heroku-buildpack-ruby.
        STDOUT
      end

      it "handles a missing buildpack URL arg" do
        stderr, stdout = execute("buildpack:set")
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku buildpack:set BUILDPACK_URL.
 !    Must specify target buildpack URL.
        STDERR
        expect(stdout).to eq("")
      end

      it "sets the buildpack URL with index" do
        stderr, stdout = execute("buildpack:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using https://github.com/heroku/heroku-buildpack-ruby.
        STDOUT
      end

      context "with one existing buildpack" do
        before(:each) do
          Excon.stubs.shift
          Excon.stubs.shift
          Excon.stub({:method => :get, :path => "/apps/example/buildpack-installations"},
            {
            :body => [
              {
                "buildpack" => {
                  "url" => "https://github.com/heroku/heroku-buildpack-java"
                },
                "ordinal" => 0
              }
            ],
            :status => 200
            })
        end

        it "overwrites an existing buildpack URL at index" do
          stub_put(
            "https://github.com/heroku/heroku-buildpack-ruby"
          )
          stderr, stdout = execute("buildpack:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using https://github.com/heroku/heroku-buildpack-ruby.
          STDOUT
        end
      end

      context "with two existing buildpack" do
        before(:each) do
          Excon.stubs.shift
          Excon.stubs.shift
          Excon.stub({:method => :get, :path => "/apps/example/buildpack-installations"},
          {
            :body => [
              {
                "buildpack" => {
                  "url" => "https://github.com/heroku/heroku-buildpack-java"
                },
                "ordinal" => 0
              },
              {
                "buildpack" => {
                  "url" => "https://github.com/heroku/heroku-buildpack-nodejs"
                },
                "ordinal" => 1
              }
            ],
            :status => 200
            })
          end

          it "overwrites an existing buildpack URL at index" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-ruby",
              "https://github.com/heroku/heroku-buildpack-nodejs"
            )
            stderr, stdout = execute("buildpack:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using https://github.com/heroku/heroku-buildpack-ruby.
            STDOUT
          end

          it "adds buildpack URL to the end of list" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-java",
              "https://github.com/heroku/heroku-buildpack-nodejs",
              "https://github.com/heroku/heroku-buildpack-ruby"
            )
            stderr, stdout = execute("buildpack:set -i 99 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using https://github.com/heroku/heroku-buildpack-ruby.
            STDOUT
          end
        end
    end

    describe "clear" do
      it "clears the buildpack URL" do
        stderr, stdout = execute("buildpack:clear")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpack(s) cleared. Next release on example will detect buildpack normally.
        STDOUT
      end

      it "clears and warns about buildpack URL config var" do
        execute("config:set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpack:clear")
        expect(stderr).to eq <<-STDERR
WARNING: The BUILDPACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpack(s) cleared.
        STDOUT
      end

      it "clears and warns about language pack URL config var" do
        execute("config:set LANGUAGE_PACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpack:clear")
        expect(stderr).to eq <<-STDERR
WARNING: The LANGUAGE_PACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpack(s) cleared.
        STDOUT
      end
    end
  end
end
