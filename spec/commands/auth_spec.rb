require File.dirname(__FILE__) + '/../base'

module Heroku::Command
	describe Auth do
		before do
			@cli = prepare_command(Auth)
		end

		it "reads credentials from the credentials file" do
			sandbox = "#{Dir.tmpdir}/cli_spec_#{Process.pid}"
			File.open(sandbox, "w") { |f| f.write "user\npass\n" }
			@cli.stub!(:credentials_file).and_return(sandbox)
			@cli.read_credentials.should == %w(user pass)
		end

		it "takes the user from the first line and the password from the second line" do
			@cli.stub!(:read_credentials).and_return(%w(user pass))
			@cli.user.should == 'user'
			@cli.password.should == 'pass'
		end

		it "asks for credentials when the file doesn't exist" do
			sandbox = "#{Dir.tmpdir}/cli_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@cli.stub!(:credentials_file).and_return(sandbox)
			@cli.should_receive(:ask_for_credentials).and_return([ 'u', 'p'])
			@cli.should_receive(:save_credentials)
			@cli.get_credentials.should == [ 'u', 'p' ]
		end

		it "writes the credentials to a file" do
			sandbox = "#{Dir.tmpdir}/cli_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@cli.stub!(:credentials_file).and_return(sandbox)
			@cli.stub!(:credentials).and_return(['one', 'two'])
			@cli.should_receive(:set_credentials_permissions)
			@cli.write_credentials
			File.read(sandbox).should == "one\ntwo\n"
		end

		it "sets ~/.heroku/credentials to be readable only by the user" do
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

		it "writes credentials and uploads authkey when credentials are saved" do
			@cli.stub!(:credentials)
			@cli.should_receive(:write_credentials)
			Heroku::Command.should_receive(:run_internal).with('keys:add', [])
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