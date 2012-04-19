require "spec_helper"
require "heroku/command/sharing"

module Heroku::Command
  describe Sharing do

    context("list") do

      it "lists message with no collaborators" do
        stub_core.list_collaborators.returns([])
        stderr, stdout = execute("sharing")
        stderr.should == ""
        stdout.should == <<-STDOUT
myapp has no collaborators
STDOUT
      end

      it "lists collaborators" do
        stub_core.list_collaborators.returns([{:email => "joe@example.com"}])
        stderr, stdout = execute("sharing")
        stderr.should == ""
        stdout.should == <<-STDOUT
joe@example.com
STDOUT
      end

    end

    it "adds collaborators with default access to view only" do
      stub_core.add_collaborator("myapp", "joe@example.com")
      stderr, stdout = execute("sharing:add joe@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
joe@example.com added to myapp collaborators
STDOUT
    end

    it "removes collaborators" do
      stub_core.remove_collaborator("myapp", "joe@example.com")
      stderr, stdout = execute("sharing:remove joe@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
joe@example.com removed from myapp collaborators
STDOUT
    end

    it "transfers ownership" do
      stub_core.update("myapp", :transfer_owner => "joe@example.com")
      stderr, stdout = execute("sharing:transfer joe@example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
myapp ownership transfered. New owner is joe@example.com
STDOUT
    end
  end

end
