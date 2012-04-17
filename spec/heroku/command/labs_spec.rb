require "spec_helper"
require "heroku/command/labs"

module Heroku::Command
  describe Labs do
    before do
      @labs = prepare_command(Labs)
      @labs.heroku.stub!(:info).and_return({})
    end

    it "lists no features if developer is not enrolled" do
      stub_core.list_features("myapp").returns([])
      stderr, stdout = execute("labs")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== App Features (myapp)

=== User Features (user)
STDOUT
    end

    it "lists features if developer is enrolled" do
      stub_core.list_features("myapp").returns([])
      stderr, stdout = execute("labs")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== App Features (myapp)

=== User Features (user)
STDOUT
    end

    it "displays details of a feature" do
      stub_core.get_feature('myapp', 'example').returns({'docs' => 'http://devcenter.heroku.com/labs-example', 'name' => 'example', 'summary' => 'example feature'})
      stderr, stdout = execute("labs:info example")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== example
Summary: example feature
Docs:    http://devcenter.heroku.com/labs-example
STDOUT
    end

    it "shows usage if no feature name is specified for info" do
      stderr, stdout = execute("labs:info")
      stderr.should == <<-STDERR
 !    Usage: heroku labs:info FEATURE
STDERR
      # FIXME: sometimes stdout is "failed"
      #stdout.should == "failed"
    end

    it "enables a feature" do
      stub_core.enable_feature('myapp', 'example')
      stderr, stdout = execute("labs:enable example")
      stderr.should == ""
      stdout.should == <<-STDOUT
----> Enabling example for myapp... done
WARNING: This feature is experimental and may change or be removed without notice.
STDOUT
    end

    it "shows usage if no feature name is specified for enable" do
      stderr, stdout = execute("labs:enable")
      stderr.should == <<-STDERR
 !    Usage: heroku labs:enable FEATURE
STDERR
      # FIXME: sometimes stdout is "failed"
      #stdout.should == "failed"
    end

    it "disables a feature" do
      stub_core.disable_feature('myapp', 'example')
      stderr, stdout = execute("labs:disable example")
      stderr.should == ""
      stdout.should == <<-STDOUT
----> Disabling example for myapp... done
STDOUT
    end

    it "shows usage if no feature name is specified for disable" do
      stderr, stdout = execute("labs:disable")
      stderr.should == <<-STDERR
 !    Usage: heroku labs:disable FEATURE
STDERR
      # FIXME: sometimes stdout is "failed"
      #stdout.should == "failed"
    end
  end
end
