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
        Heroku::Command.stub(:current_options).and_return(:confirm => "example")
        @base.stub(:app).and_return("example")
        @base.confirm_command.should be_true
      end

      it "does not confirms the app via --confirm on a mismatch" do
        Heroku::Command.stub(:current_options).and_return(:confirm => "badapp")
        @base.stub(:app).and_return("example")
        lambda { @base.confirm_command}.should raise_error CommandFailed
      end

      it "confirms the app interactively via ask" do
        @base.stub(:app).and_return("example")
        @base.stub(:ask).and_return("example")
        Heroku::Command.stub(:current_options).and_return({})
        @base.confirm_command.should be_true
      end

      it "fails if the interactive confirm doesn't match" do
        @base.stub(:app).and_return("example")
        @base.stub(:ask).and_return("badresponse")
        Heroku::Command.stub(:current_options).and_return({})
        capture_stderr do
          lambda { @base.confirm_command }.should raise_error(SystemExit)
        end.should == <<-STDERR
 !    Confirmation did not match example. Aborted.
        STDERR
      end
    end

    context "detecting the app" do
      it "attempts to find the app via the --app option" do
        @base.stub!(:options).and_return(:app => "example")
        @base.app.should == "example"
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
        @base.stub!(:options).and_return(:app => "example")
        @base.app.should == "example"
        ENV.delete('HEROKU_APP')
      end

      it "read remotes from git config" do
        Dir.stub(:chdir)
        File.should_receive(:exists?).with(".git").and_return(true)
        @base.should_receive(:git).with('remote -v').and_return(<<-REMOTES)
staging\tgit@heroku.com:example-staging.git (fetch)
staging\tgit@heroku.com:example-staging.git (push)
production\tgit@heroku.com:example.git (fetch)
production\tgit@heroku.com:example.git (push)
other\tgit@other.com:other.git (fetch)
other\tgit@other.com:other.git (push)
        REMOTES

        @heroku = mock
        @heroku.stub(:host).and_return('heroku.com')
        @base.stub(:heroku).and_return(@heroku)

        # need a better way to test internal functionality
        @base.send(:git_remotes, '/home/dev/example').should == { 'staging' => 'example-staging', 'production' => 'example' }
      end

      it "gets the app from remotes when there's only one app" do
        @base.stub!(:git_remotes).and_return({ 'heroku' => 'example' })
        @base.stub!(:git).with("config heroku.remote").and_return("")
        @base.app.should == 'example'
      end

      it "accepts a --remote argument to choose the app from the remote name" do
        @base.stub!(:git_remotes).and_return({ 'staging' => 'example-staging', 'production' => 'example' })
        @base.stub!(:options).and_return(:remote => "staging")
        @base.app.should == 'example-staging'
      end

      it "reads from .heroku_default if exists" do
        FakeFS do
          Dir.stub(:pwd) { '/myapppath' }
          FileUtils.mkdir(Dir.pwd)
          default_file_path = "#{Dir.pwd}/.heroku_default"
          File.should_receive(:file?).with(default_file_path).and_return(true)
          File.open(default_file_path, "w") do |f|
            f.puts("default_app")
          end
          @base.app.should == 'default_app'
          FileUtils.rm_rf(Dir.pwd)
        end
      end

      it "overrides .heroku_default when explicitly specified" do
        FakeFS do
          Dir.stub(:pwd) { '/myapppath' }
          FileUtils.mkdir(Dir.pwd)
          default_file_path = "#{Dir.pwd}/.heroku_default"
          File.open(default_file_path, "w") do |f|
            f.puts("default_app")
          end
          @base.stub!(:options).and_return(:app => "example")
          @base.app.should == "example"
          FileUtils.rm_rf(Dir.pwd)
        end
      end

    end

    it "raises when cannot determine which app is it" do
      @base.stub!(:git_remotes).and_return({ 'staging' => 'example-staging', 'production' => 'example' })
      lambda { @base.app }.should raise_error(Heroku::Command::CommandFailed)
    end
  end

end
