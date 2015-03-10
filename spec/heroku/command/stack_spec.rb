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
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== example Available Stacks
  aspen-mri-1.8.6
  bamboo-ree-1.8.7
  cedar-10 (beta)
* bamboo-mri-1.9.2

STDOUT
      end

      it "migrate should succeed" do
        stderr, stdout = execute("stack:migrate bamboo-ree-1.8.7")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Stack set. Next release on example will use bamboo-ree-1.8.7.
Run `git push heroku master` to create a new release on bamboo-ree-1.8.7.
STDOUT
      end


    end
  end
end
