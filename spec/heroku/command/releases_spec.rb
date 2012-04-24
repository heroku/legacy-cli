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
        { "name" => "v5", "descr" => "Description5", "user" => "User6", "created_at" => (Time.now - 18005).to_s }
      ])
    end

    it "should list releases" do
      time = Time.now
      Time.should_receive(:now).exactly(12).times.and_return(time)
      @stderr, @stdout = execute("releases")
      @stderr.should == ""
      @stdout.should == <<-STDOUT
Rel  Change        By     When
---  ------------  -----  -------------------
v5   Description5  User6  5h ago
v4   Description4  User4  5m ago
v3   Description3  User3  5s ago
v2   Description2  User2  2011-02-02 00:00:00
v1   Description1  User1  2011-01-01 00:00:00
STDOUT
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
      lambda { execute("releases:info") }.should fail_command("Specify a release")
    end

    it "shows info for a single release" do
      stderr, stdout = execute("releases:info v1")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== Release v1
Change:      Description1
By:          User1
When:        2011-01-01 00:00:00
Addons:      addon:one, addon:two
Config:      foo => bar
STDOUT
    end
  end

  describe "rollback" do
    it "rolls back to the latest release with no argument" do
      stub_core.rollback("myapp", nil).returns("v10")
      stderr, stdout = execute("releases:rollback")
      stderr.should == ""
      stdout.should == <<-STDOUT
Rolled back to v10
STDOUT
    end

    it "rolls back to the specified release" do
      stub_core.rollback("myapp", "v11").returns("v11")
      stderr, stdout = execute("releases:rollback v11")
      stderr.should == ""
      stdout.should == <<-STDOUT
Rolled back to v11
STDOUT
    end
  end

end


