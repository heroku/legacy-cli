require "spec_helper"
require "heroku/command/releases"

describe Heroku::Command::Releases do

  describe "releases" do
    before(:each) do
      stub_core.releases("myapp").returns([
        { "name" => "v1", "descr" => "Description1", "user" => "User1", "created_at" => "2011-01-01" },
        { "name" => "v2", "descr" => "Description2", "user" => "User2", "created_at" => "2011-02-02" },
        { "name" => "v3", "descr" => "Description3", "user" => "User3", "created_at" => (Time.now - 5).to_s },
        { "name" => "v4", "descr" => "Description4", "user" => "User4", "created_at" => (Time.now - 305).to_s },
        { "name" => "v6", "descr" => "Description5", "user" => "User6", "created_at" => (Time.now - 18005).to_s }
      ])
      @stderr, @stdout = execute("releases")
    end

    it "should list releases" do
      @stderr.should == ""
      @stdout.should =~ /v1\s+Description1\s+User1\s+2011-01-01/
      @stdout.should =~ /v2\s+Description2\s+User2\s+2011-02-02/
    end

    it "should calculate time deltas" do
      @stderr.should == ""
      @stdout.should =~ /2011-01-01/
      @stdout.should =~ /\d seconds ago/
      @stdout.should =~ /\d minutes ago/
      @stdout.should =~ /\d hours ago/
    end
  end

  describe "releases:info" do
    before(:each) do
      stub_core.release("myapp", "v1").returns({
        "name" => "v1",
        "descr" => "Description1",
        "user" => "User1",
        "created_at" => "2011-01-01",
        "addons" => [ "addon:one", "addon:two" ],
        "env" => { "foo" => "bar" }
      })
    end

    it "requires a release to be specified" do
      lambda { execute "releases:info" }.should fail_command("Specify a release")
    end

    it "shows info for a single release" do
      stderr, stdout = execute("releases:info v1")
      stderr.should == ""
      stdout.should =~ /=== Release v1/
      stdout.should =~ /Change:      Description1/
      stdout.should =~ /By:          User1/
      stdout.should =~ /When:        2011-01-01/
      stdout.should =~ /Addons:      addon:one, addon:two/
      stdout.should =~ /Config:      foo => bar/
    end
  end

  describe "rollback" do
    it "rolls back to the latest release with no argument" do
      stub_core.rollback("myapp", nil).returns("v10")
      stderr, stdout = execute("releases:rollback")
      stderr.should == ""
      stdout.should =~ /Rolled back to v10/
    end

    it "rolls back to the specified release" do
      stub_core.rollback("myapp", "v11").returns("v11")
      stderr, stdout = execute("releases:rollback v11")
      stderr.should == ""
      stdout.should =~ /Rolled back to v11/
    end
  end

end


