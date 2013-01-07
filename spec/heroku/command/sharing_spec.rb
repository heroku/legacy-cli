require "spec_helper"
require "heroku/command/sharing"

module Heroku::Command
  describe Sharing do

    before(:each) do
      stub_core
      api.post_app("name" => "example")
    end

    after(:each) do
      api.delete_app("example")
    end

    context("list") do

      it "lists collaborators" do
        api.post_collaborator("example", "collaborator@example.com")
        stderr, stdout = execute("sharing")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== example Collaborators
collaborator@example.com
email@example.com

STDOUT
      end

    end

    it "adds collaborators with default access to view only" do
      stderr, stdout = execute("sharing:add collaborator@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Adding collaborator@example.com to example collaborators... done
STDOUT
    end

    it "removes collaborators" do
      api.post_collaborator("example", "collaborator@example.com")
      stderr, stdout = execute("sharing:remove collaborator@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removing collaborator@example.com from example collaborators... done
STDOUT
    end

    it "transfers ownership" do
      api.post_collaborator("example", "collaborator@example.com")
      stderr, stdout = execute("sharing:transfer collaborator@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Transferring example to collaborator@example.com... done
STDOUT
    end
  end

end
