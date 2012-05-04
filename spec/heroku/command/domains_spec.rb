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
No domain names for myapp
STDOUT
      end

      it "lists domains when some exist" do
        api.post_domain("myapp", "example.com")
        stderr, stdout = execute("domains")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== Domain names for myapp
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
      lambda { execute("domains:add") }.should raise_error(CommandFailed, /Usage:/)
    end

    it "shows usage if blank domain specified for add" do
      lambda { execute("domains:add  ") }.should raise_error(CommandFailed, /Usage:/)
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
      lambda { execute("domains:remove") }.should raise_error(CommandFailed, /Usage:/)
    end

    it "shows usage if blank domain specified for remove" do
      lambda { execute("domains:remove  ") }.should raise_error(CommandFailed, /Usage:/)
    end

    it "removes all domain names" do
      stub_core.remove_domains("myapp")
      stderr, stdout = execute("domains:clear")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removing all domain names for myapp... done
STDOUT
    end
  end
end
