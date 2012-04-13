require "spec_helper"
require "heroku/command/apps"

module Heroku::Command
  describe Apps do
    before(:each) do
      @cli = prepare_command(Apps)
      @cli.stub(:options).and_return(:app => "myapp")
      @data = {
        :addons         => [],
        :collaborators  => [],
        :database_size  => 5*1024*1024,
        :git_url        => 'git@heroku.com/myapp.git',
        :name           => 'myapp',
        :repo_size      => 2*1024,
        :web_url        => 'http://myapp.heroku.com/'
      }
    end

    context("info") do

      before(:each) do
        stub_core.info('myapp').returns(@data)
      end

      it "displays app info, converts bytes to kbs/mbs" do
        stderr, stdout = execute("apps:info")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== myapp
Database Size: 5M
Git URL:       git@heroku.com/myapp.git
Repo Size:     2k
Web URL:       http://myapp.heroku.com/
STDOUT
      end

      it "gets explicit app from --app" do
        @cli.stub!(:options).and_return(:app => "myapp")
        @cli.heroku.should_receive(:info).and_return(@data)
        @cli.info
      end

      it "gets implied app from current git dir" do
        @cli.stub!(:options).and_return({})
        @cli.stub!(:extract_app_in_dir).and_return('myapp')
        @cli.heroku.should_receive(:info).with('myapp').and_return(@data)
        @cli.info
      end

      it "shows raw app info when --raw option is used" do
        stub_core.info('myapp').returns({ :foo => "bar" })
        stderr, stdout = execute("apps:info --raw")
        stderr.should == ""
        stdout.should == <<-STDOUT
foo=bar
STDOUT
      end

    end

    context("create") do

      it "without a name" do
        @cli.heroku.should_receive(:create_app).with(nil, {:stack => nil}).and_return({
          "create_status" => "creating",
          "name"          => "untitled-123",
          "git_url"       => "git@heroku.com:untitled-123.git",
          "web_url"       => "http://untitled-123.herokuapp.com",
          "stack"         => "bamboo-mri-1.9.2"
        })
        @cli.heroku.should_receive(:create_complete?).with("untitled-123").and_return(true)
        @cli.should_receive(:create_git_remote).with('heroku', 'git@heroku.com:untitled-123.git')
        @cli.create
      end

      it "with a name" do
        @cli.stub!(:args).and_return(["myapp"])
        @cli.heroku.should_receive(:create_app).with('myapp', {:stack => nil}).and_return({
          "create_status" => "creating",
          "name"          => "myapp",
          "git_url"       => "git@heroku.com:myapp.git",
          "web_url"       => "http://myapp.herokuapp.com",
          "stack"         => "bamboo-mri-1.9.2"
        })
        @cli.heroku.should_receive(:create_complete?).with("myapp").and_return(true)
        @cli.should_receive(:create_git_remote).with('heroku', 'git@heroku.com:myapp.git')
        @cli.create
      end

      it "with addons" do
        @cli.stub!(:args).and_return(["addonapp"])
        @cli.stub!(:options).and_return(:addons => "foo:bar,fred:barney")
        @cli.heroku.should_receive(:create_app).with('addonapp', {:stack => nil}).and_return({
          "create_status" => "creating",
          "name"          => "addonapp",
          "git_url"       => "git@heroku.com:addonapp.git",
          "web_url"       => "http://addonapp.herokuapp.com",
          "stack"         => "bamboo-mri-1.9.2"
        })
        @cli.heroku.should_receive(:create_complete?).with("addonapp").and_return(true)
        @cli.heroku.should_receive(:install_addon).with("addonapp", "foo:bar")
        @cli.heroku.should_receive(:install_addon).with("addonapp", "fred:barney")
        @cli.should_receive(:create_git_remote).with('heroku', 'git@heroku.com:addonapp.git')
        @cli.create
      end

      it "with a buildpack" do
        @cli.stub!(:args).and_return(["buildpackapp"])
        @cli.stub!(:options).and_return(:buildpack => "http://example.org/buildpack.git")
        @cli.heroku.should_receive(:create_app).with('buildpackapp', {:stack => nil}).and_return({
          "create_status" => "creating",
          "name"          => "buildpackapp",
          "git_url"       => "git@heroku.com:buildpackapp.git",
          "web_url"       => "http://buildpackapp.herokuapp.com",
          "stack"         => "bamboo-mri-1.9.2"
        })
        @cli.heroku.should_receive(:create_complete?).with("buildpackapp").and_return(true)
        @cli.heroku.should_receive(:add_config_vars).with("buildpackapp", "BUILDPACK_URL" => "http://example.org/buildpack.git")
        @cli.should_receive(:create_git_remote).with('heroku', 'git@heroku.com:buildpackapp.git')
        @cli.create
      end

      it "with an alternate remote name" do
        @cli.stub!(:options).and_return(:remote => "alternate")
        @cli.stub!(:args).and_return([ 'alternate-remote' ])
        @cli.heroku.should_receive(:create_app).with("alternate-remote", {:stack => nil}).and_return({
          "create_status" => "creating",
          "name"          => "alternate-remote",
          "git_url"       => "git@heroku.com:alternate-remote.git",
          "web_url"       => "http://alternate-remote.herokuapp.com",
          "stack"         => "bamboo-mri-1.9.2"
        })
        @cli.heroku.should_receive(:create_complete?).with("alternate-remote").and_return(true)
        @cli.should_receive(:create_git_remote).with('alternate', 'git@heroku.com:alternate-remote.git')
        @cli.create
      end

    end

    context("index") do

      it "succeeds" do
        stub_core.list.returns([["myapp", "user"]])
        stderr, stdout = execute("apps")
        stderr.should == ""
        stdout.should == <<-STDOUT
myapp
STDOUT
      end

    end

    context("rename") do

      it "succeeds" do
        stub_core.update('myapp', { :name => 'myapp2' })
        stub_core.info.returns({:git_url => 'git@heroku.com:myapp2.git', :web_url => 'http://myapp2.herokuapp.com'})
        stderr, stdout = execute("apps:rename myapp2")
        stderr.should == ""
        stdout.should == <<-STDOUT
http://myapp2.herokuapp.com | git@heroku.com:myapp2.git
Don't forget to update your Git remotes on any local checkouts.
STDOUT
      end

      it "displays an error if no name is specified" do
        Heroku::Command.should_receive(:error).with(/Must specify a new name/)
        run "rename --app bar"
      end

    end

    context("destroy") do

      it "with app explicitly specified with --app and user confirmation" do
        @cli.stub!(:options).and_return(:app => "myapp")
        @cli.should_receive(:confirm_command).and_return(true)
        @cli.heroku.stub!(:info).and_return({:git_url => 'git@heroku.com:myapp.git'})
        @cli.heroku.should_receive(:destroy).with('myapp')
        @cli.destroy
      end

      it "fails with explicit app but no confirmation" do
        @cli.stub!(:options).and_return(:app => "myapp")
        @cli.should_receive(:confirm_command).and_return(false)
        @cli.heroku.stub!(:info).and_return({:git_url => 'git@heroku.com:myapp.git'})
        @cli.heroku.should_not_receive(:destroy)
        @cli.destroy
      end

      it "fails with implicit app but no confirmation" do
        @cli.stub!(:app).and_return('myapp')
        @cli.heroku.stub!(:info).and_return({:git_url => 'git@heroku.com:myapp.git'})
        @cli.heroku.should_not_receive(:destroy)
        @cli.destroy
      end

    end

    context "Git Integration" do
      include SandboxHelper
      before(:all) do
        # setup a git dir to serve as a remote
        @git = "/tmp/git_spec_#{Process.pid}"
        FileUtils.mkdir_p(@git)
        FileUtils.cd(@git) { |d| `git --bare init` }
      end

      after(:all) do
        FileUtils.rm_rf(@git)
      end

      before(:each) do
        stub_core.create_app(nil, {:stack => nil}).returns({
          "create_status" => "creating",
          "name"          => "myapp",
          "git_url"       => "git@heroku.com:myapp.git",
          "web_url"       => "http://myapp.herokuapp.com",
          "stack"         => "bamboo-mri-1.9.2"
        })
        stub_core.create_complete?('myapp').returns(true)
      end

      it "creates adding heroku to git remote" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create")
          stderr.should == ""
          stdout.should == <<-STDOUT
Creating myapp... done, stack is bamboo-mri-1.9.2
http://myapp.herokuapp.com | git@heroku.com:myapp.git
Git remote heroku added
STDOUT
          bash("git remote").strip.should match(/^heroku$/)
        end
      end

      it "creates adding a custom git remote" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create --remote myremote")
          stderr.should == ""
          stdout.should == <<-STDOUT
Creating myapp... done, stack is bamboo-mri-1.9.2
http://myapp.herokuapp.com | git@heroku.com:myapp.git
Git remote myremote added
STDOUT
          bash("git remote").strip.should match(/^myremote$/)
        end
      end

      it "doesn't add a git remote if it already exists" do
        with_blank_git_repository do
          bash "git remote add heroku #{@git}"
          stderr, stdout = execute("apps:create")
          stderr.should == ""
          stdout.should == <<-STDOUT
Creating myapp... done, stack is bamboo-mri-1.9.2
http://myapp.herokuapp.com | git@heroku.com:myapp.git
STDOUT
        end
      end

      it "renames updating the corresponding heroku git remote" do
        with_blank_git_repository do
          bash "git remote add github     git@github.com:test/test.git"
          bash "git remote add production git@heroku.com:myapp.git"
          bash "git remote add staging    git@heroku.com:myapp-staging.git"

          stub_core.update
          stub_core.info('myapp2').returns({:git_url => 'git@heroku.com:myapp2.git', :web_url => 'http://myapp2.herokuapp.com/'})
          stderr, stdout = execute("apps:rename myapp2")

          remotes = bash("git remote -v")
          remotes.should include('git@github.com:test/test.git')
          remotes.should include('git@heroku.com:myapp-staging.git')
          remotes.should include('git@heroku.com:myapp2.git')
          remotes.should_not include('git@heroku.com:myapp.git')
        end
      end

      it "destroys removing any remotes pointing to the app" do
        with_blank_git_repository do
          bash("git remote add heroku git@heroku.com:myapp.git")

          stub_core.info('myapp').returns({:git_url => 'git@heroku.com:myapp2.git', :web_url => 'http://myapp2.herokuapp.com/'})
          stub_core.destroy
          stderr, stdout = execute("apps:destroy --confirm myapp")

          bash("git remote").strip.should_not include('heroku')
        end
      end
    end
  end
end
