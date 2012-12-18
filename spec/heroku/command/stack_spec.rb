require "spec_helper"
require "heroku/command/stack"

module Heroku::Command
  describe Stack do
    describe "index" do
      before(:each) do
        stub_core
        api.post_app("name" => "example", "stack" => "bamboo-mri-1.9.2")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "index should provide list" do
        stderr, stdout = execute("stack")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== example Available Stacks
  aspen-mri-1.8.6
  bamboo-ree-1.8.7
  cedar (beta)
* bamboo-mri-1.9.2

STDOUT
      end

      it "migrate should succeed" do
        stderr, stdout = execute("stack:migrate bamboo-ree-1.8.7")
        stderr.should == ""
        stdout.should == <<-STDOUT
-----> Preparing to migrate example
       bamboo-mri-1.9.2 -> bamboo-ree-1.8.7

       NOTE: Additional details here

       -----> Migration prepared.
       Run 'git push heroku master' to execute migration.
STDOUT
      end


    end
  end
end
