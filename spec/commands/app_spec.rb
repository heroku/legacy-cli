require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe App do
    before(:each) do
      @cli = prepare_command(App)
    end

    it "shows app info, converting bytes to kbs/mbs" do
      @cli.stub!(:args).and_return(['myapp'])
      @cli.heroku.should_receive(:info).with('myapp').and_return({ :name => 'myapp', :collaborators => [], :addons => [], :repo_size => 2*1024, :database_size => 5*1024*1024 })
      @cli.should_receive(:display).with('=== myapp')
      @cli.should_receive(:display).with('Web URL:        http://myapp.heroku.com/')
      @cli.should_receive(:display).with('Repo size:      2k')
      @cli.should_receive(:display).with('Data size:      5M')
      @cli.info
    end

    it "shows app info using the --app syntax" do
      @cli.stub!(:args).and_return(['--app', 'myapp'])
      @cli.heroku.should_receive(:info).with('myapp').and_return({ :collaborators => [], :addons => []})
      @cli.info
    end

    it "shows app info reading app from current git dir" do
      @cli.stub!(:args).and_return([])
      @cli.stub!(:extract_app_in_dir).and_return('myapp')
      @cli.heroku.should_receive(:info).with('myapp').and_return({ :collaborators => [], :addons => []})
      @cli.info
    end

    it "creates without a name" do
      @cli.heroku.should_receive(:create_request).with(nil, {:stack => nil}).and_return("untitled-123")
      @cli.heroku.should_receive(:create_complete?).with("untitled-123").and_return(true)
      @cli.create
    end

    it "creates with a name" do
      @cli.stub!(:args).and_return([ 'myapp' ])
      @cli.heroku.should_receive(:create_request).with('myapp', {:stack => nil}).and_return("myapp")
      @cli.heroku.should_receive(:create_complete?).with("myapp").and_return(true)
      @cli.create
    end

    it "creates with addons" do
      @cli.stub!(:args).and_return([ 'addonapp', '--addons', 'foo:bar,fred:barney' ])
      @cli.heroku.should_receive(:create_request).with('addonapp', {:stack => nil}).and_return("addonapp")
      @cli.heroku.should_receive(:create_complete?).with("addonapp").and_return(true)
      @cli.heroku.should_receive(:install_addon).with("addonapp", "foo:bar")
      @cli.heroku.should_receive(:install_addon).with("addonapp", "fred:barney")
      @cli.create
    end

    it "renames an app" do
      @cli.stub!(:args).and_return([ 'myapp2' ])
      @cli.heroku.should_receive(:update).with('myapp', { :name => 'myapp2' })
      @cli.rename
    end

    it "runs a rake command on the app" do
      @cli.stub!(:args).and_return(([ 'db:migrate' ]))
      @cli.heroku.should_receive(:start).
        with('myapp', 'rake db:migrate', attached=true).
        and_return(['foo', 'bar', 'baz'])
      @cli.rake
    end

    it "runs a single console command on the app" do
      @cli.stub!(:args).and_return([ '2+2' ])
      @cli.heroku.should_receive(:console).with('myapp', '2+2')
      @cli.console
    end

    it "offers a console, opening and closing the session with the client" do
      @console = mock('heroku console')
      @cli.stub!(:console_history_read)
      @cli.stub!(:console_history_add)
      @cli.heroku.should_receive(:console).with('myapp').and_yield(@console)
      Readline.should_receive(:readline).and_return('exit')
      @cli.console
    end

    it "asks to restart servers" do
      @cli.heroku.should_receive(:restart).with('myapp')
      @cli.restart
    end

    it "scales dynos" do
      @cli.stub!(:args).and_return(['+4'])
      @cli.heroku.should_receive(:set_dynos).with('myapp', '+4').and_return(7)
      @cli.dynos
    end

    it "destroys the app specified with --app if user confirms" do
      @cli.stub!(:ask).and_return('y')
      @cli.stub!(:args).and_return(['--app', 'myapp'])
      @cli.heroku.stub!(:info).and_return({})
      @cli.heroku.should_receive(:destroy).with('myapp')
      @cli.destroy
    end

    it "doesn't destroy the app if the user doesn't confirms" do
      @cli.stub!(:ask).and_return('no')
      @cli.stub!(:args).and_return(['--app', 'myapp'])
      @cli.heroku.stub!(:info).and_return({})
      @cli.heroku.should_not_receive(:destroy)
      @cli.destroy
    end

    it "doesn't destroy the app in the current dir" do
      @cli.stub!(:extract_app).and_return('myapp')
      @cli.heroku.should_not_receive(:destroy)
      @cli.destroy
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

      it "creates adding heroku to git remote" do
        with_blank_git_repository do
          @cli.heroku.should_receive(:create_request).and_return('myapp')
          @cli.heroku.should_receive(:create_complete?).with('myapp').and_return(true)
          @cli.create
          bash("git remote").strip.should == 'heroku'
        end
      end

      it "creates adding a custom git remote" do
        with_blank_git_repository do
          @cli.stub!(:args).and_return([ 'myapp', '--remote', 'myremote' ])
          @cli.heroku.should_receive(:create_request).and_return('myapp')
          @cli.heroku.should_receive(:create_complete?).with('myapp').and_return(true)
          @cli.create
          bash("git remote").strip.should == 'myremote'
        end
      end

      it "doesn't add a git remote if it already exists" do
        with_blank_git_repository do
          @cli.heroku.should_receive(:create_request).and_return('myapp')
          @cli.heroku.should_receive(:create_complete?).with('myapp').and_return(true)
          bash "git remote add heroku #{@git}"
          @cli.create
        end
      end

      it "renames updating the corresponding heroku git remote" do
        with_blank_git_repository do
          bash "git remote add github     git@github.com:test/test.git"
          bash "git remote add production git@heroku.com:myapp.git"
          bash "git remote add staging    git@heroku.com:myapp-staging.git"

          @cli.heroku.stub!(:update)
          @cli.stub!(:args).and_return([ 'myapp2' ])
          @cli.rename
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
          @cli.stub!(:args).and_return(['--app', 'myapp'])
          @cli.heroku.stub!(:info).and_return({})
          @cli.stub!(:ask).and_return('y')
          @cli.heroku.should_receive(:destroy)
          @cli.destroy
          bash("git remote").strip.should == ''
        end
      end
    end
  end
end
