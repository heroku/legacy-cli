require "spec_helper"
require "heroku/command/releases"

describe Heroku::Command::Releases do

  before(:each) do
    stub_core
  end

  describe "releases" do

    before(:each) do
      api.post_app("name" => "myapp", "stack" => "cedar")
      api.put_config_vars("myapp", { 'FOO_BAR'  => 'BAZ' })
      api.put_config_vars("myapp", { 'BAR_BAZ'  => 'QUX' })
      api.put_config_vars("myapp", { 'BAZ_QUX'  => 'QUUX' })
      api.put_config_vars("myapp", { 'QUX_QUUX' => 'XYZZY' })
      api.put_config_vars("myapp", { 'SUPER_LONG_CONFIG_VAR_TO_GET_PAST_THE_TRUNCATION_LIMIT' => 'VALUE' })
      Heroku::Command::Releases.any_instance.should_receive(:time_ago).exactly(5).times.and_return('1s ago', '30s ago', '1m ago', '1h ago', '2012/01/02 12:34:56')
    end

    after(:each) do
      api.delete_app("myapp")
    end

    it "should list releases" do
      @stderr, @stdout = execute("releases")
      @stderr.should == ""
      @stdout.should == <<-STDOUT
=== myapp Releases
v5  Config add SUPER_LONG_CONFIG_VAR_TO_GE..  email@example.com  1s ago
v4  Config add QUX_QUUX                       email@example.com  30s ago
v3  Config add BAZ_QUX                        email@example.com  1m ago
v2  Config add BAR_BAZ                        email@example.com  1h ago
v1  Config add FOO_BAR                        email@example.com  2012/01/02 12:34:56

STDOUT
    end

  end

  describe "releases:info" do
    before(:each) do
      api.post_app("name" => "myapp", "stack" => "cedar")
      api.put_config_vars("myapp", { 'FOO_BAR' => 'BAZ' })
    end

    after(:each) do
      api.delete_app("myapp")
    end

    it "requires a release to be specified" do
      stderr, stdout = execute("releases:info")
      stderr.should == <<-STDERR
 !    Usage: heroku releases:info RELEASE
STDERR
      stdout.should == ""
    end

    it "shows info for a single release" do
      Heroku::Command::Releases.any_instance.should_receive(:time_ago).and_return('0s ago')
      stderr, stdout = execute("releases:info v1")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== Release v1
By:     email@example.com
Change: Config add FOO_BAR
When:   0s ago

=== v1 Config Vars
BUNDLE_WITHOUT:      development:test
DATABASE_URL:        postgres://username:password@ec2-123-123-123-123.compute-1.amazonaws.com/username
LANG:                en_US.UTF-8
RACK_ENV:            production
SHARED_DATABASE_URL: postgres://username:password@ec2-123-123-123-123.compute-1.amazonaws.com/username
STDOUT
    end

    it "shows info for a single release in shell compatible format" do
      Heroku::Command::Releases.any_instance.should_receive(:time_ago).and_return('0s ago')
      stderr, stdout = execute("releases:info v1 --shell")
      stderr.should == ""
      stdout.should == <<-STDOUT
=== Release v1
By:     email@example.com
Change: Config add FOO_BAR
When:   0s ago

=== v1 Config Vars
BUNDLE_WITHOUT=development:test
DATABASE_URL=postgres://username:password@ec2-123-123-123-123.compute-1.amazonaws.com/username
LANG=en_US.UTF-8
RACK_ENV=production
SHARED_DATABASE_URL=postgres://username:password@ec2-123-123-123-123.compute-1.amazonaws.com/username
STDOUT
    end
  end

  describe "rollback" do
    before(:each) do
      api.post_app("name" => "myapp", "stack" => "cedar")
      api.put_config_vars("myapp", { 'FOO_BAR' => 'BAZ' })
      api.put_config_vars("myapp", { 'BAR_BAZ' => 'QUX' })
      api.put_config_vars("myapp", { 'BAZ_QUX' => 'QUUX' })
    end

    after(:each) do
      api.delete_app("myapp")
    end

    it "rolls back to the latest release with no argument" do
      stderr, stdout = execute("releases:rollback")
      stderr.should == ""
      stdout.should == <<-STDOUT
Rolling back myapp... done, v2
STDOUT
    end

    it "rolls back to the specified release" do
      stderr, stdout = execute("releases:rollback v1")
      stderr.should == ""
      stdout.should == <<-STDOUT
Rolling back myapp... done, v1
STDOUT
    end
  end

end


