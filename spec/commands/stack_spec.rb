require File.expand_path("../base", File.dirname(__FILE__))

module Salesforce::Command
  describe Stack do
    before do
      @cli = prepare_command(Stack)
    end
    describe "list" do
      context "when --all is specified" do
        describe "salesforce" do
          it "should receive list_stacks with show_deprecated = true" do
            @cli.stub!(:args).and_return(['--all'])
            @cli.salesforce.should_receive(:list_stacks).with('myapp', { :include_deprecated => true }).and_return([])
            @cli.list
          end
        end
      end
    end
  end
end
