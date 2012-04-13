require "spec_helper"
require "heroku/command/domains"

module Heroku::Command
  describe Domains do

    it "lists domains" do
      stub_core.info("myapp").returns({:web_url => "http://myapp.herokuapp.com"})
      stub_core.list_domains("myapp").returns([])
      stderr, stdout = execute("domains")
      stderr.should == ""
      stdout.should == <<-STDOUT
No domain names for myapp.herokuapp.com
STDOUT
    end

    it "adds domain names" do
      stub_core.add_domain("myapp", "example.com")
      stderr, stdout = execute("domains:add example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Added example.com as a custom domain name for myapp
STDOUT
    end

    it "shows usage if no domain specified for add" do
      lambda { execute("domains:add") }.should raise_error(CommandFailed, /Usage:/)
    end

    it "shows usage if blank domain specified for add" do
      lambda { execute("domains:add  ") }.should raise_error(CommandFailed, /Usage:/)
    end

    it "removes domain names" do
      stub_core.remove_domain("myapp", "example.com")
      stderr, stdout = execute("domains:remove example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removed example.com as a custom domain name for myapp
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
Removed all domain names for myapp
STDOUT
    end
  end
end
