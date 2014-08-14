require "spec_helper"

require "heroku/command/labs"

module Heroku::Command
  describe Labs do

    before(:each) do
      stub_core
      api.post_app("name" => "example", "stack" => "cedar")
    end

    after(:each) do
      api.delete_app("example")
    end

    it "lists available features" do
      stderr, stdout = execute("labs:list")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== User Features (email@example.com)
[ ] sumo-rankings  Heroku Sumo ranks and visualizes the scale of your app, and suggests the optimum combination of dynos and add-ons to take it to the next level.

=== App Features (example)
[+] sigterm-all       When stopping a dyno, send SIGTERM to all processes rather than only to the root process.
[ ] user_env_compile  Add user config vars to the environment during slug compilation
STDOUT
    end

    it "lists enabled features" do
      stub_core.list_features("example").returns([])
      stderr, stdout = execute("labs")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== User Features (email@example.com)
[ ] sumo-rankings  Heroku Sumo ranks and visualizes the scale of your app, and suggests the optimum combination of dynos and add-ons to take it to the next level.

=== App Features (example)
[+] sigterm-all       When stopping a dyno, send SIGTERM to all processes rather than only to the root process.
[ ] user_env_compile  Add user config vars to the environment during slug compilation
STDOUT
    end

    it "displays details of a feature" do
      stderr, stdout = execute("labs:info user_env_compile")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== user_env_compile
Docs:    http://devcenter.heroku.com/articles/labs-user-env-compile
Summary: Add user config vars to the environment during slug compilation
STDOUT
    end

    it "shows usage if no feature name is specified for info" do
      stderr, stdout = execute("labs:info")
      expect(stderr).to eq <<-STDERR
 !    Usage: heroku labs:info FEATURE
 !    Must specify FEATURE for info.
STDERR
      expect(stdout).to eq("")
    end

    it "enables a feature" do
      stderr, stdout = execute("labs:enable user_env_compile")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Enabling user_env_compile for example... done
WARNING: This feature is experimental and may change or be removed without notice.
For more information see: http://devcenter.heroku.com/articles/labs-user-env-compile
STDOUT
    end

    it "shows usage if no feature name is specified for enable" do
      stderr, stdout = execute("labs:enable")
      expect(stderr).to eq <<-STDERR
 !    Usage: heroku labs:enable FEATURE
 !    Must specify FEATURE to enable.
STDERR
      expect(stdout).to eq("")
    end

    it "disables a feature" do
      api.post_feature('user_env_compile', 'example')
      stderr, stdout = execute("labs:disable user_env_compile")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Disabling user_env_compile for example... done
STDOUT
    end

    it "shows usage if no feature name is specified for disable" do
      stderr, stdout = execute("labs:disable")
      expect(stderr).to eq <<-STDERR
 !    Usage: heroku labs:disable FEATURE
 !    Must specify FEATURE to disable.
STDERR
      expect(stdout).to eq("")
    end
  end
end
