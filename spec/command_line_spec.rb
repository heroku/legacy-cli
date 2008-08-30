require File.dirname(__FILE__) + '/base'

describe Heroku::CommandLine do
	before do
		@cli = Heroku::CommandLine.new
		@cli.stub!(:display)
		@cli.stub!(:print)
		@cli.stub!(:ask_for_credentials).and_raise("ask_for_credentials should not be called by specs")
	end

	describe "credentials" do
		it "reads credentials from the credentials file" do
			sandbox = "/tmp/cli_spec_#{Process.pid}"
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
			sandbox = "/tmp/cli_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@cli.stub!(:credentials_file).and_return(sandbox)
			@cli.should_receive(:ask_for_credentials).and_return([ 'u', 'p'])
			@cli.should_receive(:save_credentials)
			@cli.get_credentials.should == [ 'u', 'p' ]
		end

		it "writes the credentials to a file" do
			sandbox = "/tmp/cli_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@cli.stub!(:credentials_file).and_return(sandbox)
			@cli.stub!(:credentials).and_return(['one', 'two'])
			@cli.should_receive(:set_credentials_permissions)
			@cli.write_credentials
			File.read(sandbox).should == "one\ntwo\n"
		end

		it "sets ~/.heroku/credentials to be readable only by the user" do
			sandbox = "/tmp/cli_spec_#{Process.pid}"
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
			@cli.should_receive(:add_key)
			@cli.save_credentials
		end

		it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
			@cli.stub!(:write_credentials)
			@cli.stub!(:retry_login?).and_return(false)
			@cli.should_receive(:add_key).and_raise(RestClient::Unauthorized)
			@cli.should_receive(:delete_credentials)
			lambda { @cli.save_credentials }.should raise_error(RestClient::Unauthorized)
		end

		it "save_credentials deletes the credentials when there's no authkey" do
			@cli.stub!(:write_credentials)
			@cli.should_receive(:add_key).and_raise(RuntimeError)
			@cli.should_receive(:delete_credentials)
			lambda { @cli.save_credentials }.should raise_error
		end

		it "save_credentials deletes the credentials when the authkey is weak" do
			@cli.stub!(:write_credentials)
			@cli.should_receive(:add_key).and_raise(RestClient::RequestFailed)
			@cli.should_receive(:delete_credentials)
			lambda { @cli.save_credentials }.should raise_error
		end

		it "asks for login again when not authorized, for three times" do
			@cli.stub!(:write_credentials)
			@cli.stub!(:delete_credentials)
			@cli.stub!(:add_key).and_raise(RestClient::Unauthorized)
			@cli.should_receive(:ask_for_credentials).exactly(4).times
			lambda { @cli.save_credentials }.should raise_error(RestClient::Unauthorized)
		end

		it "deletes the credentials file" do
			FileUtils.should_receive(:rm_f).with(@cli.credentials_file)
			@cli.delete_credentials
		end
	end

	describe "key management" do
		it "finds the user's ssh key in ~/ssh/id_rsa.pub" do
			@cli.stub!(:home_directory).and_return('/home/joe')
			File.should_receive(:exists?).with('/home/joe/.ssh/id_rsa.pub').and_return(true)
			@cli.find_key.should == '/home/joe/.ssh/id_rsa.pub'
		end

		it "finds the user's ssh key in ~/ssh/id_dsa.pub" do
			@cli.stub!(:home_directory).and_return('/home/joe')
			File.should_receive(:exists?).with('/home/joe/.ssh/id_rsa.pub').and_return(false)
			File.should_receive(:exists?).with('/home/joe/.ssh/id_dsa.pub').and_return(true)
			@cli.find_key.should == '/home/joe/.ssh/id_dsa.pub'
		end

		it "raises an exception if neither id_rsa or id_dsa were found" do
			@cli.stub!(:home_directory).and_return('/home/joe')
			File.stub!(:exists?).and_return(false)
			lambda { @cli.find_key }.should raise_error(Heroku::CommandLine::UserError)
		end
	end

	describe "deprecated key management" do
		it "gets pub keys from the user's home directory" do
			@cli.should_receive(:home_directory).and_return('/Users/joe')
			File.should_receive(:exists?).with('/Users/joe/.ssh/id_xyz.pub').and_return(true)
			File.should_receive(:read).with('/Users/joe/.ssh/id_xyz.pub').and_return('ssh-xyz somehexkey')
			@cli.authkey_type('xyz').should == 'ssh-xyz somehexkey'
		end

		it "gets the rsa key" do
			@cli.stub!(:authkey_type).with('rsa').and_return('ssh-rsa somehexkey')
			@cli.authkey.should == 'ssh-rsa somehexkey'
		end

		it "gets the dsa key when there's no rsa" do
			@cli.stub!(:authkey_type).with('rsa').and_return(nil)
			@cli.stub!(:authkey_type).with('dsa').and_return('ssh-dsa somehexkey')
			@cli.authkey.should == 'ssh-dsa somehexkey'
		end

		it "raises a friendly error message when no key is found" do
			@cli.stub!(:authkey_type).with('rsa').and_return(nil)
			@cli.stub!(:authkey_type).with('dsa').and_return(nil)
			lambda { @cli.authkey }.should raise_error
		end

		it "accepts a custom key via the -k parameter" do
			Object.redefine_const(:ARGV, ['-k', '/Users/joe/sshkeys/mykey.pub'])
			@cli.should_receive(:authkey_read).with('/Users/joe/sshkeys/mykey.pub').and_return('ssh-rsa somehexkey')
			@cli.extract_key!
			@cli.authkey.should == 'ssh-rsa somehexkey'
		end

		it "extracts options from ARGV" do
			Object.redefine_const(:ARGV, %w( a b --something value c d ))
			@cli.extract_option(ARGV, '--something').should == 'value'
			ARGV.should == %w( a b c d )
		end

		it "rejects options outside valid values for ARGV" do
			Object.redefine_const(:ARGV, %w( -boolean_option t ))
			lambda { @cli.extract_argv_option('-boolean_option', %w( true false )) }.should raise_error
		end

		it "uploads the ssh authkey (deprecated in favor of add_key)" do
			@cli.should_receive(:extract_key!)
			@cli.should_receive(:authkey).and_return('my key')
			heroku = mock("heroku client")
			@cli.should_receive(:init_heroku).and_return(heroku)
			heroku.should_receive(:add_key).with('my key')
			@cli.upload_authkey
		end

		it "gets the home directory from HOME when running on *nix" do
			ENV.should_receive(:[]).with('HOME').and_return(@home)
			@cli.stub!(:running_on_windows?).and_return(false)
			@cli.home_directory.should == @home
		end

		it "gets the home directory from USERPROFILE when running on windows" do
			ENV.should_receive(:[]).with('USERPROFILE').and_return(@home)
			@cli.stub!(:running_on_windows?).and_return(true)
			@cli.home_directory.should == @home
		end

		it "detects it's running on windows" do
			Object.redefine_const(:RUBY_PLATFORM, 'i386-mswin32')
			@cli.should be_running_on_windows
		end

		it "doesn't consider cygwin as windows" do
			Object.redefine_const(:RUBY_PLATFORM, 'i386-cygwin')
			@cli.should_not be_running_on_windows
		end
	end

	describe "execute" do
		it "executes an action" do
			@cli.should_receive(:my_action).with(%w(arg1 arg2))
			@cli.execute('my_action', %w(arg1 arg2))
		end

		it "catches unauthorized errors" do
			@cli.should_receive(:my_action).and_raise(RestClient::Unauthorized)
			@cli.should_receive(:display).with('Authentication failure')
			@cli.execute('my_action', 'args')
		end

		it "parses rails-format error xml" do
			@cli.parse_error_xml('<errors><error>Error 1</error><error>Error 2</error></errors>').should == 'Error 1 / Error 2'
		end

		it "does not catch general exceptions, those are shown to the user as normal" do
			@cli.should_receive(:my_action).and_raise(RuntimeError)
			lambda { @cli.execute('my_action', 'args') }.should raise_error(RuntimeError)
		end
	end

	describe "app actions" do
		before do
			@cli.instance_variable_set('@credentials', %w(user pass))
		end

		it "shows app info" do
			@cli.heroku.should_receive(:info).with('myapp').and_return({ :name => 'myapp', :collaborators => [] })
			@cli.heroku.stub!(:domain).and_return('heroku.com')
			@cli.should_receive(:display).with('=== myapp')
			@cli.should_receive(:display).with('Web URL:        http://myapp.heroku.com/')
			@cli.info([ 'myapp' ])
		end

		it "creates without a name" do
			@cli.heroku.should_receive(:create).with(nil, {}).and_return("untitled-123")
			@cli.create([])
		end

		it "creates with a name" do
			@cli.heroku.should_receive(:create).with('myapp', {}).and_return("myapp")
			@cli.create([ 'myapp' ])
		end

		it "updates app" do
			@cli.heroku.should_receive(:update).with('myapp', { :name => 'myapp2', :share_public => true, :production => true })
			@cli.update([ 'myapp', '--name', 'myapp2', '--public', 'true', '--mode', 'production' ])
		end

		it "clones the app (deprecated in favor of straight git clone)" do
			@cli.should_receive(:system).with('git clone git@heroku.com:myapp.git')
			@cli.clone([ 'myapp' ])
		end
	end

	describe "collaborators" do
		before do
			@cli.instance_variable_set('@credentials', %w(user pass))
		end

		it "list collaborators when there's just the app name" do
			@cli.heroku.should_receive(:list_collaborators).and_return([])
			@cli.collaborators(['myapp'])
		end

		it "add collaborators with default access to view only" do
			@cli.heroku.should_receive(:add_collaborator).with('myapp', 'joe@example.com', 'view')
			@cli.collaborators(['myapp', '--add', 'joe@example.com'])
		end

		it "add collaborators with edit access" do
			@cli.heroku.should_receive(:add_collaborator).with('myapp', 'joe@example.com', 'edit')
			@cli.collaborators(['myapp', '--add', 'joe@example.com', '--access', 'edit'])
		end

		it "updates collaborators" do
			@cli.heroku.should_receive(:update_collaborator).with('myapp', 'joe@example.com', 'view')
			@cli.collaborators(['myapp', '--update', 'joe@example.com', '--access', 'view'])
		end

		it "removes collaborators" do
			@cli.heroku.should_receive(:remove_collaborator).with('myapp', 'joe@example.com')
			@cli.collaborators(['myapp', '--remove', 'joe@example.com'])
		end
	end
end
