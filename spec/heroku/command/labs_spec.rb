require "spec_helper"
require "heroku/command/labs"

module Heroku::Command
  describe Labs do
    before do
      @labs = prepare_command(Labs)
      @labs.heroku.stub!(:info).and_return({})
    end
    
    it "lists no features if developer is not enrolled" do
      Heroku::Auth.stub!("user").and_return("user")
      @labs.heroku.should_receive(:list_features).with('myapp').and_return([])
      @labs.index
    end

    it "lists features if developer is enrolled" do
      Heroku::Auth.stub!("user").and_return("user")
      @labs.heroku.should_receive(:list_features).with('myapp').and_return([])
      @labs.index
    end
    
    it "displays details of a feature" do
      @labs.stub!(:args).and_return(['example'])
      @labs.heroku.should_receive(:get_feature).with('myapp', 'example').and_return({'docs' => 'http://devcenter.heroku.com/labs-example', 'name' => 'example', 'summary' => 'example feature'})
      @labs.info
    end
    
    it "shows usage if no feature name is specified for info" do
      @labs.stub!(:args).and_return([])
      STDERR.should_receive(:puts).with(" !    Usage: heroku labs:info FEATURE")
      lambda { @labs.info }.should raise_error(SystemExit)
    end
    
    it "enables a feature" do
      @labs.stub!(:args).and_return(['example'])
      @labs.heroku.should_receive(:enable_feature).with('myapp', 'example')
      @labs.enable
    end
    
    it "shows usage if no feature name is specified for enable" do
      @labs.stub!(:args).and_return([])
      STDERR.should_receive(:puts).with(" !    Usage: heroku labs:enable FEATURE")
      lambda { @labs.enable }.should raise_error(SystemExit)
    end
    
    it "disables a feature" do
      @labs.stub!(:args).and_return(['example'])
      @labs.heroku.should_receive(:disable_feature).with('myapp', 'example')
      @labs.disable
    end
    
    it "shows usage if no feature name is specified for disable" do
      @labs.stub!(:args).and_return([])
      STDERR.should_receive(:puts).with(" !    Usage: heroku labs:disable FEATURE")
      lambda { @labs.disable }.should raise_error(SystemExit)
    end
  end
end
