require "spec_helper"
require "heroku/command/stack"

module Heroku::Command
  describe Stack do
    describe "index" do
      context "when --all is specified" do
        describe "heroku" do
          it "should receive list_stacks with show_deprecated = true" do
            stub_core.list_stacks('myapp', { :include_deprecated => true }).returns([{"beta" => true, "current" => true, "name" => "cedar"}])
            stderr, stdout = execute("stack --all")
            stderr.should == ""
            stdout.should == <<-STDOUT
* cedar (beta)
STDOUT
          end
        end
      end
    end
  end
end
