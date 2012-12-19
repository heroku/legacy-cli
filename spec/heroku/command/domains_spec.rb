require "spec_helper"
require "heroku/command/domains"

module Heroku::Command
  describe Domains do

    before(:all) do
      api.post_app("name" => "example", "stack" => "cedar")
      api.post_addon("example", "custom_domains:basic")
    end

    after(:all) do
      api.delete_app("example")
    end

    before(:each) do
      stub_core
    end

    context("index") do

      it "lists message with no domains" do
        stderr, stdout = execute("domains")
        stderr.should == ""
        stdout.should == <<-STDOUT
example has no domain names.
STDOUT
      end

      it "lists domains when some exist" do
        api.post_domain("example", "example.com")
        stderr, stdout = execute("domains")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== example Domain Names
example.com

STDOUT
        api.delete_domain("example", "example.com")
      end

    end

    it "adds domain names" do
      stderr, stdout = execute("domains:add example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Adding example.com to example... done
STDOUT
      api.delete_domain("example", "example.com")
    end

    it "shows usage if no domain specified for add" do
      stderr, stdout = execute("domains:add")
      stderr.should == <<-STDERR
 !    Usage: heroku domains:add DOMAIN
 !    Must specify DOMAIN to add.
      STDERR
    end

    it "removes domain names" do
      api.post_domain("example", "example.com")
      stderr, stdout = execute("domains:remove example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removing example.com from example... done
STDOUT
    end

    it "shows usage if no domain specified for remove" do
      stderr, stdout = execute("domains:remove")
      stderr.should == <<-STDERR
 !    Usage: heroku domains:remove DOMAIN
 !    Must specify DOMAIN to remove.
      STDERR
    end

    it "removes all domain names" do
      stub_core.remove_domains("example")
      stderr, stdout = execute("domains:clear")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removing all domain names from example... done
STDOUT
    end
  end
end
