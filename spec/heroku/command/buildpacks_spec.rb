require "spec_helper"
require "heroku/command/buildpacks"

module Heroku::Command
  describe Buildpacks do

    def stub_put(*buildpacks)
      Excon.stub({
        :method => :put,
        :path => "/apps/example/buildpack-installations",
        :body => {"updates" => buildpacks.map{|bp| {"buildpack" => bp}}}.to_json
      },
      {:status => 200})
    end

    def stub_get(*buildpacks)
      Excon.stub({:method => :get, :path => "/apps/example/buildpack-installations"},
      {
        :body => buildpacks.map.with_index { |bp, i|
          {
            "buildpack" => {
              "url" => bp
            },
            "ordinal" => i
          }
        },
        :status => 200
      })
    end

    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar-14")

      Excon.stub({:method => :put, :path => "/apps/example/buildpack-installations"},
        {:status => 200})
      stub_get("https://github.com/heroku/heroku-buildpack-ruby")
    end

    after(:each) do
      Excon.stubs.shift
      Excon.stubs.shift
      api.delete_app("example")
    end

    describe "index" do
      it "displays the buildpack URL" do
        stderr, stdout = execute("buildpacks")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== example Buildpack URL
https://github.com/heroku/heroku-buildpack-ruby
        STDOUT
      end

      context "with no buildpack URL set" do
        before(:each) do
          Excon.stubs.shift
          stub_get
        end

        it "does not display a buildpack URL" do
          stderr, stdout = execute("buildpacks")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
example has no Buildpack URL set.
          STDOUT
        end
      end

      context "with two buildpack URLs set" do
        before(:each) do
          Excon.stubs.shift
          stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-ruby")
        end

        it "does not display a buildpack URL" do
          stderr, stdout = execute("buildpacks")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
=== example Buildpack URLs
1. https://github.com/heroku/heroku-buildpack-java
2. https://github.com/heroku/heroku-buildpack-ruby
          STDOUT
        end
      end
    end

    describe "set" do
      context "with no buildpacks" do
        before do
          Excon.stubs.shift
          stub_get
        end

        it "sets the buildpack URL" do
          stderr, stdout = execute("buildpacks:set https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
          STDOUT
        end

        it "handles a missing buildpack URL arg" do
          stderr, stdout = execute("buildpacks:set")
          expect(stderr).to eq <<-STDERR
 !    Usage: heroku buildpacks:set BUILDPACK_URL.
 !    Must specify target buildpack URL.
          STDERR
          expect(stdout).to eq("")
        end

        it "sets the buildpack URL with index" do
          stderr, stdout = execute("buildpacks:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
          STDOUT
        end
      end

      context "with one existing buildpack" do
        context "successfully" do
          before(:each) do
            Excon.stubs.shift
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java")
          end

          it "overwrites an existing buildpack URL at index" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-ruby")
            stderr, stdout = execute("buildpacks:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
            STDOUT
          end
        end

        context "unsuccessfully" do
          before(:each) do
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-ruby")
          end

          it "fails if buildpack is already set" do
            stderr, stdout = execute("buildpacks:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    The buildpack https://github.com/heroku/heroku-buildpack-ruby is already set on your app.
            STDOUT
          end
        end
      end

      context "with two existing buildpacks" do
        context "successfully" do
          before(:each) do
            Excon.stubs.shift
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-nodejs")
          end

          it "overwrites an existing buildpack URL at index" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-ruby",
              "https://github.com/heroku/heroku-buildpack-nodejs")
            stderr, stdout = execute("buildpacks:set -i 1 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-ruby
  2. https://github.com/heroku/heroku-buildpack-nodejs
Run `git push heroku master` to create a new release using these buildpacks.
            STDOUT
          end

          it "adds buildpack URL to the end of list" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-java",
              "https://github.com/heroku/heroku-buildpack-nodejs",
              "https://github.com/heroku/heroku-buildpack-ruby")
            stderr, stdout = execute("buildpacks:set -i 3 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-nodejs
  3. https://github.com/heroku/heroku-buildpack-ruby
Run `git push heroku master` to create a new release using these buildpacks.
            STDOUT
          end

          it "adds buildpack URL to the very end of list" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-java",
              "https://github.com/heroku/heroku-buildpack-nodejs",
              "https://github.com/heroku/heroku-buildpack-ruby")
            stderr, stdout = execute("buildpacks:set -i 99 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack set. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-nodejs
  3. https://github.com/heroku/heroku-buildpack-ruby
Run `git push heroku master` to create a new release using these buildpacks.
            STDOUT
          end
        end

        context "unsuccessfully" do
          before(:each) do
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-nodejs")
          end

          it "fails if buildpack is already set" do
            stderr, stdout = execute("buildpacks:set -i 2 https://github.com/heroku/heroku-buildpack-java")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    The buildpack https://github.com/heroku/heroku-buildpack-java is already set on your app.
            STDOUT
          end
        end
      end
    end

    describe "add" do
      context "with no buildpacks" do
        before(:each) do
          Excon.stubs.shift
          stub_get
        end

        it "adds the buildpack URL" do
          stderr, stdout = execute("buildpacks:add https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
          STDOUT
        end

        it "handles a missing buildpack URL arg" do
          stderr, stdout = execute("buildpacks:add")
          expect(stderr).to eq <<-STDERR
 !    Usage: heroku buildpacks:add BUILDPACK_URL.
 !    Must specify target buildpack URL.
          STDERR
          expect(stdout).to eq("")
        end

        it "adds the buildpack URL with index" do
          stderr, stdout = execute("buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
          STDOUT
        end
      end

      context "with one existing buildpack" do
        before(:each) do
          Excon.stubs.shift
          Excon.stubs.shift
          stub_get("https://github.com/heroku/heroku-buildpack-java")
        end

        it "inserts a buildpack URL at index" do
          stub_put("https://github.com/heroku/heroku-buildpack-ruby", "https://github.com/heroku/heroku-buildpack-java")
          stderr, stdout = execute("buildpacks:add -i 1 https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-ruby
  2. https://github.com/heroku/heroku-buildpack-java
Run `git push heroku master` to create a new release using these buildpacks.
          STDOUT
        end

        it "adds a buildpack URL to the end of the list" do
          stub_put("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-ruby")
          stderr, stdout = execute("buildpacks:add https://github.com/heroku/heroku-buildpack-ruby")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-ruby
Run `git push heroku master` to create a new release using these buildpacks.
          STDOUT
        end
      end

      context "with two existing buildpacks" do
        context "successfully" do
          before(:each) do
            Excon.stubs.shift
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-nodejs")
          end

          it "inserts a buildpack URL at index" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-java",
              "https://github.com/heroku/heroku-buildpack-ruby",
              "https://github.com/heroku/heroku-buildpack-nodejs")
            stderr, stdout = execute("buildpacks:add -i 2 https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-ruby
  3. https://github.com/heroku/heroku-buildpack-nodejs
Run `git push heroku master` to create a new release using these buildpacks.
            STDOUT
          end

          it "adds a buildpack URL to the end of the list" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-java",
              "https://github.com/heroku/heroku-buildpack-nodejs",
              "https://github.com/heroku/heroku-buildpack-ruby")
            stub_put("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-nodejs")
            stderr, stdout = execute("buildpacks:add https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack added. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-nodejs
  3. https://github.com/heroku/heroku-buildpack-ruby
Run `git push heroku master` to create a new release using these buildpacks.
            STDOUT
          end
        end

        context "successfully" do
          before(:each) do
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-nodejs")
          end

          it "inserts a buildpack URL at index" do
            stderr, stdout = execute("buildpacks:add https://github.com/heroku/heroku-buildpack-java")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    The buildpack https://github.com/heroku/heroku-buildpack-java is already set on your app.
            STDOUT
          end
        end
      end
    end

    describe "clear" do
      it "clears the buildpack URL" do
        stderr, stdout = execute("buildpacks:clear")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Buildpacks cleared. Next release on example will detect buildpack normally.
        STDOUT
      end

      it "clears and warns about buildpack URL config var" do
        execute("config:set BUILDPACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpacks:clear")
        expect(stderr).to eq <<-STDERR
WARNING: The BUILDPACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpacks cleared.
        STDOUT
      end

      it "clears and warns about language pack URL config var" do
        execute("config:set LANGUAGE_PACK_URL=https://github.com/heroku/heroku-buildpack-ruby")
        stderr, stdout = execute("buildpacks:clear")
        expect(stderr).to eq <<-STDERR
WARNING: The LANGUAGE_PACK_URL config var is still set and will be used for the next release
        STDERR
        expect(stdout).to eq <<-STDOUT
Buildpacks cleared.
        STDOUT
      end
    end

    describe "remove" do
      context "with no buildpacks" do
        before(:each) do
          Excon.stubs.shift
          stub_get
        end

        it "reports an error removing index" do
          stderr, stdout = execute("buildpacks:remove -i 1")
          expect(stdout).to eq("")
          expect(stderr).to eq <<-STDOUT
 !    No buildpacks were found. Next release on example will detect buildpack normally.
          STDOUT
        end

        it "reports an error removing buildpack_url" do
          stderr, stdout = execute("buildpacks:remove https://github.com/heroku/heroku-buildpack-ruby")
          expect(stdout).to eq("")
          expect(stderr).to eq <<-STDOUT
 !    No buildpacks were found. Next release on example will detect buildpack normally.
          STDOUT
        end
      end

      context "with one buildpack" do
        context "successfully" do
          before(:each) do
            Excon.stubs.shift
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-ruby")
            stub_put
          end

          it "removes index" do
            stderr, stdout = execute("buildpacks:remove -i 1")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack removed. Next release on example will detect buildpack normally.
            STDOUT
          end

          it "removes url" do
            stderr, stdout = execute("buildpacks:remove https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack removed. Next release on example will detect buildpack normally.
            STDOUT
          end
        end

        context "unsuccessfully" do
          before(:each) do
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java")
          end

          it "validates arguments" do
            stderr, stdout = execute("buildpacks:remove -i 1 https://github.com/heroku/heroku-buildpack-java")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    Please choose either index or Buildpack URL, but not both.
            STDOUT
          end

          it "checks if index is in range" do
            stderr, stdout = execute("buildpacks:remove -i 9")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    Invalid index. Only valid value is 1.
            STDOUT
          end

          it "checks if buildpack_url is found" do
            stderr, stdout = execute("buildpacks:remove https://github.com/heroku/heroku-buildpack-foobar")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    Buildpack not found. Nothing was removed.
            STDOUT
          end
        end
      end

      context "with two buildpacks" do
        context "successfully" do
          before(:each) do
            Excon.stubs.shift
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-ruby")
          end

          it "removes index" do
            stub_put("https://github.com/heroku/heroku-buildpack-java")
            stderr, stdout = execute("buildpacks:remove -i 2")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack removed. Next release on example will use https://github.com/heroku/heroku-buildpack-java.
Run `git push heroku master` to create a new release using this buildpack.
            STDOUT
          end

          it "removes index" do
            stub_put("https://github.com/heroku/heroku-buildpack-ruby")
            stderr, stdout = execute("buildpacks:remove -i 1")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack removed. Next release on example will use https://github.com/heroku/heroku-buildpack-ruby.
Run `git push heroku master` to create a new release using this buildpack.
            STDOUT
          end

          it "removes url" do
            stub_put("https://github.com/heroku/heroku-buildpack-java")
            stderr, stdout = execute("buildpacks:remove https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack removed. Next release on example will use https://github.com/heroku/heroku-buildpack-java.
Run `git push heroku master` to create a new release using this buildpack.
            STDOUT
          end
        end

        context "unsuccessfully" do
          before(:each) do
            Excon.stubs.shift
            stub_get("https://github.com/heroku/heroku-buildpack-java", "https://github.com/heroku/heroku-buildpack-nodejs")
          end

          it "checks if index is in range" do
            stderr, stdout = execute("buildpacks:remove -i 9")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    Invalid index. Please choose a value between 1 and 2
            STDOUT
          end

          it "checks if index or url is provided" do
            stderr, stdout = execute("buildpacks:remove")
            expect(stdout).to eq("")
            expect(stderr).to eq <<-STDOUT
 !    Usage: heroku buildpacks:remove [BUILDPACK_URL].
 !    Must specify a buildpack to remove, either by index or URL.
            STDOUT
          end
        end
      end

      context "with three buildpacks" do
        context "successfully" do
          before(:each) do
            Excon.stubs.shift
            Excon.stubs.shift
            stub_get(
            "https://github.com/heroku/heroku-buildpack-java",
            "https://github.com/heroku/heroku-buildpack-nodejs",
            "https://github.com/heroku/heroku-buildpack-ruby")
          end

          it "removes index" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-java",
              "https://github.com/heroku/heroku-buildpack-ruby")
            stderr, stdout = execute("buildpacks:remove -i 2")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack removed. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-ruby
Run `git push heroku master` to create a new release using these buildpacks.
            STDOUT
          end

          it "removes url" do
            stub_put(
              "https://github.com/heroku/heroku-buildpack-java",
              "https://github.com/heroku/heroku-buildpack-nodejs")
            stderr, stdout = execute("buildpacks:remove https://github.com/heroku/heroku-buildpack-ruby")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Buildpack removed. Next release on example will use:
  1. https://github.com/heroku/heroku-buildpack-java
  2. https://github.com/heroku/heroku-buildpack-nodejs
Run `git push heroku master` to create a new release using these buildpacks.
            STDOUT
          end
        end
      end
    end
  end
end
