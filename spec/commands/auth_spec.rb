require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Auth do
    before do
      @cli = prepare_command(Auth)
      @sandbox = "#{Dir.tmpdir}/cli_spec_#{Process.pid}"
      File.open(@sandbox, "w") { |f| f.write "user\npass\n" }
      @cli.stub!(:credentials_file).and_return(@sandbox)
      @cli.stub!(:running_on_a_mac?).and_return(false)
    end

    after do
      FileUtils.rm_rf(@sandbox)
    end

    it "reads credentials from the credentials file" do
      @cli.read_credentials.should == %w(user pass)
    end

    it "takes the user from the first line and the password from the second line" do
      @cli.user.should == 'user'
      @cli.password.should == 'pass'
    end

    it "asks for credentials when the file doesn't exist" do
      FileUtils.rm_rf(@sandbox)
      @cli.should_receive(:ask_for_credentials).and_return([ 'u', 'p'])
      @cli.should_receive(:save_credentials)
      @cli.get_credentials.should == [ 'u', 'p' ]
    end

    it "writes the credentials to a file" do
      @cli.stub!(:credentials).and_return(['one', 'two'])
      @cli.should_receive(:set_credentials_permissions)
      @cli.write_credentials
      File.read(@sandbox).should == "one\ntwo\n"
    end

    it "sets ~/.heroku/credentials to be readable only by the user" do
      unless RUBY_PLATFORM =~ /mswin32|mingw32/
        sandbox = "#{Dir.tmpdir}/cli_spec_#{Process.pid}"
        FileUtils.rm_rf(sandbox)
        FileUtils.mkdir_p(sandbox)
        fname = "#{sandbox}/file"
        system "touch #{fname}"
        @cli.stub!(:credentials_file).and_return(fname)
        @cli.set_credentials_permissions
        File.stat(sandbox).mode.should == 040700
        File.stat(fname).mode.should == 0100600
      end
    end

    it "writes credentials and uploads authkey when credentials are saved" do
      @cli.stub!(:credentials)
      @cli.should_receive(:write_credentials)
      Heroku::Command.should_receive(:run_internal).with('keys:add', [])
      @cli.save_credentials
    end

    it "doesn't upload authkey with --ignore-keys" do
      @cli.stub!(:credentials)
      @cli.stub!(:write_credentials)
      @cli.stub!(:args).and_return(['--ignore-keys'])
      Heroku::Command.should_receive(:run_internal).with('auth:check', anything)
      @cli.save_credentials
    end

    it "preserves the args when running keys:add" do
      @cli.stub!(:write_credentials)
      @cli.stub!(:credentials)
      @cli.stub!(:args).and_return(['mykey.pub'])
      Heroku::Command.should_receive(:run_internal).with('keys:add', ['mykey.pub'])
      @cli.save_credentials
    end

    it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
      @cli.stub!(:write_credentials)
      @cli.stub!(:retry_login?).and_return(false)
      Heroku::Command.should_receive(:run_internal).with('keys:add', []).and_raise(RestClient::Unauthorized)
      @cli.should_receive(:delete_credentials)
      lambda { @cli.save_credentials }.should raise_error(RestClient::Unauthorized)
    end

    it "save_credentials deletes the credentials when there's no authkey" do
      @cli.stub!(:write_credentials)
      Heroku::Command.should_receive(:run_internal).with('keys:add', []).and_raise(RuntimeError)
      @cli.should_receive(:delete_credentials)
      lambda { @cli.save_credentials }.should raise_error
    end

    it "save_credentials deletes the credentials when the authkey is weak" do
      @cli.stub!(:write_credentials)
      Heroku::Command.should_receive(:run_internal).with('keys:add', []).and_raise(RestClient::RequestFailed)
      @cli.should_receive(:delete_credentials)
      lambda { @cli.save_credentials }.should raise_error
    end

    it "asks for login again when not authorized, for three times" do
      @cli.stub!(:read_credentials)
      @cli.stub!(:write_credentials)
      @cli.stub!(:delete_credentials)
      Heroku::Command.stub!(:run_internal).with('keys:add', []).and_raise(RestClient::Unauthorized)
      @cli.should_receive(:ask_for_credentials).exactly(4).times
      lambda { @cli.save_credentials }.should raise_error(RestClient::Unauthorized)
    end

    it "deletes the credentials file" do
      FileUtils.should_receive(:rm_f).with(@cli.credentials_file)
      @cli.delete_credentials
    end
  end
end