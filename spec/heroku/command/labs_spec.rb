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
[ ] github-sync  Allow users to set up automatic GitHub deployments from Dashboard
[ ] pipelines    Pipelines adds experimental support for deploying changes between applications with a shared code base.

=== App Features (example)
[+] http-dyno-logs       Enable HTTP dyno logs using log-shuttle [alpha]
[ ] log-runtime-metrics  Emit dyno resource usage information into app logs
STDOUT
    end

    it "lists enabled features" do
      stub_core.list_features("example").returns([])
      stderr, stdout = execute("labs")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== User Features (email@example.com)
[ ] github-sync  Allow users to set up automatic GitHub deployments from Dashboard
[ ] pipelines    Pipelines adds experimental support for deploying changes between applications with a shared code base.

=== App Features (example)
[+] http-dyno-logs       Enable HTTP dyno logs using log-shuttle [alpha]
[ ] log-runtime-metrics  Emit dyno resource usage information into app logs
STDOUT
    end

    it "displays details of a feature" do
      stderr, stdout = execute("labs:info pipelines")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
=== pipelines
Docs:    https://devcenter.heroku.com/articles/using-pipelines-to-deploy-between-applications
Summary: Pipelines adds experimental support for deploying changes between applications with a shared code base.
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
      stderr, stdout = execute("labs:enable pipelines")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Enabling pipelines for email@example.com... done
WARNING: This feature is experimental and may change or be removed without notice.
For more information see: https://devcenter.heroku.com/articles/using-pipelines-to-deploy-between-applications
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
      api.post_feature('pipelines', 'example')
      stderr, stdout = execute("labs:disable pipelines")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Disabling pipelines for email@example.com... done
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
