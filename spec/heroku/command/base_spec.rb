require "spec_helper"
require "heroku/command/base"

module Heroku::Command
  describe Base do
    before do
      @base = Base.new
      allow(@base).to receive(:display)
      @client = double('heroku client', :host => 'heroku.com')
    end

    describe "confirming" do
      it "confirms the app via --confirm" do
        allow(Heroku::Command).to receive(:current_options).and_return(:confirm => "example")
        allow(@base).to receive(:app).and_return("example")
        expect(@base.confirm_command).to be_truthy
      end

      it "does not confirms the app via --confirm on a mismatch" do
        allow(Heroku::Command).to receive(:current_options).and_return(:confirm => "badapp")
        allow(@base).to receive(:app).and_return("example")
        expect { @base.confirm_command}.to raise_error CommandFailed
      end

      it "confirms the app interactively via ask" do
        allow(@base).to receive(:app).and_return("example")
        allow(@base).to receive(:ask).and_return("example")
        allow(Heroku::Command).to receive(:current_options).and_return({})
        expect(@base.confirm_command).to be_truthy
      end

      it "fails if the interactive confirm doesn't match" do
        allow(@base).to receive(:app).and_return("example")
        allow(@base).to receive(:ask).and_return("badresponse")
        allow(Heroku::Command).to receive(:current_options).and_return({})
        expect(capture_stderr do
          expect { @base.confirm_command }.to raise_error(SystemExit)
        end).to eq <<-STDERR
 !    Confirmation did not match example. Aborted.
STDERR
      end
    end

    context "detecting the app" do
      it "attempts to find the app via the --app option" do
        allow(@base).to receive(:options).and_return(:app => "example")
        expect(@base.app).to eq("example")
      end

      it "attempts to find the app via the --confirm option" do
        allow(@base).to receive(:options).and_return(:confirm => "myconfirmapp")
        expect(@base.app).to eq("myconfirmapp")
      end

      it "attempts to find the app via HEROKU_APP when not explicitly specified" do
        ENV['HEROKU_APP'] = "myenvapp"
        expect(@base.app).to eq("myenvapp")
        allow(@base).to receive(:options).and_return([])
        expect(@base.app).to eq("myenvapp")
        ENV.delete('HEROKU_APP')
      end

      it "overrides HEROKU_APP when explicitly specified" do
        ENV['HEROKU_APP'] = "myenvapp"
        allow(@base).to receive(:options).and_return(:app => "example")
        expect(@base.app).to eq("example")
        ENV.delete('HEROKU_APP')
      end

      it "read remotes from git config" do
        allow(Dir).to receive(:chdir)
        expect(File).to receive(:exists?).with(".git").and_return(true)
        expect(@base).to receive(:git).with('remote -v').and_return(<<-REMOTES)
staging\thttps://git.heroku.com/example-staging.git (fetch)
staging\thttps://git.heroku.com/example-staging.git (push)
production\thttps://git.heroku.com/example.git (fetch)
production\thttps://git.heroku.com/example.git (push)
other\tgit@other.com:other.git (fetch)
other\tgit@other.com:other.git (push)
        REMOTES

        @heroku = double
        allow(@heroku).to receive(:host).and_return('heroku.com')
        allow(@base).to receive(:heroku).and_return(@heroku)

        # need a better way to test internal functionality
        expect(@base.send(:git_remotes, '/home/dev/example')).to eq({ 'staging' => 'example-staging', 'production' => 'example' })
      end

      it "gets the app from remotes when there's only one app" do
        allow(@base).to receive(:git_remotes).and_return({ 'heroku' => 'example' })
        allow(@base).to receive(:git).with("config heroku.remote").and_return("")
        expect(@base.app).to eq('example')
      end

      it "accepts a --remote argument to choose the app from the remote name" do
        allow(@base).to receive(:git_remotes).and_return({ 'staging' => 'example-staging', 'production' => 'example' })
        allow(@base).to receive(:options).and_return(:remote => "staging")
        expect(@base.app).to eq('example-staging')
      end

      it "raises when cannot determine which app is it" do
        allow(@base).to receive(:git_remotes).and_return({ 'staging' => 'example-staging', 'production' => 'example' })
        expect { @base.app }.to raise_error(Heroku::Command::CommandFailed)
      end
    end

  end
end
