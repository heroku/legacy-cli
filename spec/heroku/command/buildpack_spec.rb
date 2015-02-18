require "spec_helper"
require "heroku/command/buildpack"

module Heroku::Command
  describe Buildpack do

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
    end

    describe "unset" do
      it "unsets the buildpack URL" do
        stderr, stdout = execute("buildpack:unset")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpack unset. Next release on example will detect buildpack normally.
        STDOUT
      end

      it "unsets and warns about buildpack URL config var" do
        execute("config:set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpack:unset")
        expect(stderr).to eq <<-STDERR
WARNING: The BUILDPACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpack unset.
        STDOUT
      end

      it "unsets and warns about language pack URL config var" do
        execute("config:set LANGUAGE_PACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpack:unset")
        expect(stderr).to eq <<-STDERR
WARNING: The LANGUAGE_PACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpack unset.
        STDOUT
      end
    end
  end
end
