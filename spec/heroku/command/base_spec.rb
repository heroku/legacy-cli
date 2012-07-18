require "spec_helper"
require "heroku/command/base"

module Heroku::Command
  describe Base do
    before do
      @base = Base.new
      @base.stub!(:display)
      @client = mock('heroku client', :host => 'heroku.com')
    end

    describe "confirming" do
      it "confirms the app via --confirm" do
        Heroku::Command.stub(:current_options).and_return(:confirm => "myapp")
        @base.stub(:app).and_return("myapp")
        @base.confirm_command.should be_true
      end

      it "does not confirms the app via --confirm on a mismatch" do
        Heroku::Command.stub(:current_options).and_return(:confirm => "badapp")
        @base.stub(:app).and_return("myapp")
        lambda { @base.confirm_command}.should raise_error CommandFailed
      end

      it "confirms the app interactively via ask" do
        @base.stub(:app).and_return("myapp")
        @base.stub(:ask).and_return("myapp")
        Heroku::Command.stub(:current_options).and_return({})
        @base.confirm_command.should be_true
      end

      it "fails if the interactive confirm doesn't match" do
        @base.stub(:app).and_return("myapp")
        @base.stub(:ask).and_return("badresponse")
        Heroku::Command.stub(:current_options).and_return({})
        capture_stderr do
          lambda { @base.confirm_command }.should raise_error(SystemExit)
        end.should == <<-STDERR
 !    Confirmation did not match myapp. Aborted.
STDERR
      end
    end

    context "detecting the app" do
      it "attempts to find the app via the --app option" do
        @base.stub!(:options).and_return(:app => "myapp")
        @base.app.should == "myapp"
      end

      it "attempts to find the app via the --confirm option" do
        @base.stub!(:options).and_return(:confirm => "myconfirmapp")
        @base.app.should == "myconfirmapp"
      end

      it "attempts to find the app via HEROKU_APP when not explicitly specified" do
        ENV['HEROKU_APP'] = "myenvapp"
        @base.app.should == "myenvapp"
        @base.stub!(:options).and_return([])
        @base.app.should == "myenvapp"
        ENV.delete('HEROKU_APP')
      end

      it "overrides HEROKU_APP when explicitly specified" do
        ENV['HEROKU_APP'] = "myenvapp"
        @base.stub!(:options).and_return(:app => "myapp")
        @base.app.should == "myapp"
        ENV.delete('HEROKU_APP')
      end

      it "read remotes from git config" do
        Dir.stub(:chdir)
        File.should_receive(:exists?).with(".git").and_return(true)
        @base.should_receive(:git).with('remote -v').and_return(<<-REMOTES)
staging\tgit@heroku.com:myapp-staging.git (fetch)
staging\tgit@heroku.com:myapp-staging.git (push)
production\tgit@heroku.com:myapp.git (fetch)
production\tgit@heroku.com:myapp.git (push)
other\tgit@other.com:other.git (fetch)
other\tgit@other.com:other.git (push)
        REMOTES

        @heroku = mock
        @heroku.stub(:host).and_return('heroku.com')
        @base.stub(:heroku).and_return(@heroku)

        # need a better way to test internal functionality
        @base.send(:git_remotes, '/home/dev/myapp').should == { 'staging' => 'myapp-staging', 'production' => 'myapp' }
      end

      it "gets the app from remotes when there's only one app" do
        @base.stub!(:git_remotes).and_return({ 'heroku' => 'myapp' })
        @base.stub!(:git).with("config heroku.remote").and_return("")
        @base.app.should == 'myapp'
      end

      it "accepts a --remote argument to choose the app from the remote name" do
        @base.stub!(:git_remotes).and_return({ 'staging' => 'myapp-staging', 'production' => 'myapp' })
        @base.stub!(:options).and_return(:remote => "staging")
        @base.app.should == 'myapp-staging'
      end

      it "raises when cannot determine which app is it" do
        @base.stub!(:git_remotes).and_return({ 'staging' => 'myapp-staging', 'production' => 'myapp' })
        lambda { @base.app }.should raise_error(Heroku::Command::CommandFailed)
      end
    end

  end
end
