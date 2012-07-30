require "spec_helper"
require "heroku/command/domains"

module Heroku::Command
  describe Domains do

    before(:all) do
      api.post_app("name" => "myapp", "stack" => "cedar")
      api.post_addon("myapp", "custom_domains:basic")
    end

    after(:all) do
      api.delete_app("myapp")
    end

    before(:each) do
      stub_core
    end

    context("index") do

      it "lists message with no domains" do
        stderr, stdout = execute("domains")
        stderr.should == ""
        stdout.should == <<-STDOUT
myapp has no domain names.
STDOUT
      end

      it "lists domains when some exist" do
        api.post_domain("myapp", "example.com")
        stderr, stdout = execute("domains")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== myapp Domain Names
example.com

STDOUT
        api.delete_domain("myapp", "example.com")
      end

    end

    it "adds domain names" do
      stderr, stdout = execute("domains:add example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Adding example.com to myapp... done
STDOUT
      api.delete_domain("myapp", "example.com")
    end

    it "shows usage if no domain specified for add" do
      stderr, stdout = execute("domains:add")
      stderr.should == <<-STDERR
 !    Usage: heroku domains:add DOMAIN
 !    Must specify DOMAIN to add.
      STDERR
    end

    it "removes domain names" do
      api.post_domain("myapp", "example.com")
      stderr, stdout = execute("domains:remove example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removing example.com from myapp... done
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
      stub_core.remove_domains("myapp")
      stderr, stdout = execute("domains:clear")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removing all domain names from myapp... done
STDOUT
    end
  end
end
