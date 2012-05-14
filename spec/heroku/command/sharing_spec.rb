require "spec_helper"
require "heroku/command/sharing"

module Heroku::Command
  describe Sharing do

    before(:each) do
      stub_core
      api.post_app("name" => "myapp")
    end

    after(:each) do
      api.delete_app("myapp")
    end

    context("list") do

      it "lists collaborators" do
        api.post_collaborator("myapp", "collaborator@example.com")
        stderr, stdout = execute("sharing")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== myapp Collaborators
collaborator@example.com
email@example.com

STDOUT
      end

    end

    it "adds collaborators with default access to view only" do
      stderr, stdout = execute("sharing:add collaborator@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Adding collaborator@example.com to myapp collaborators... done
STDOUT
    end

    it "removes collaborators" do
      api.post_collaborator("myapp", "collaborator@example.com")
      stderr, stdout = execute("sharing:remove collaborator@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removing collaborator@example.com from myapp collaborators... done
STDOUT
    end

    it "transfers ownership" do
      api.post_collaborator("myapp", "collaborator@example.com")
      stderr, stdout = execute("sharing:transfer collaborator@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Transferring myapp to collaborator@example.com... done
STDOUT
    end
  end

end
