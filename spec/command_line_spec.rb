require File.dirname(__FILE__) + '/base'

describe Heroku::CommandLine do
	before do
		@wrapper = Heroku::CommandLine.new
		@wrapper.stub!(:display)
		@wrapper.stub!(:print)
		@wrapper.stub!(:ask_for_credentials).and_raise("ask_for_credentials should not be called by specs")
	end

	describe "credentials" do
		it "reads credentials from the credentials file" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			File.open(sandbox, "w") { |f| f.write "user\npass\n" }
			@wrapper.stub!(:credentials_file).and_return(sandbox)
			@wrapper.read_credentials.should == %w(user pass)
		end

		it "takes the user from the first line and the password from the second line" do
			@wrapper.stub!(:read_credentials).and_return(%w(user pass))
			@wrapper.user.should == 'user'
			@wrapper.password.should == 'pass'
		end

		it "asks for credentials when the file doesn't exist" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@wrapper.stub!(:credentials_file).and_return(sandbox)
			@wrapper.should_receive(:ask_for_credentials).and_return([ 'u', 'p'])
			@wrapper.should_receive(:save_credentials)
			@wrapper.get_credentials.should == [ 'u', 'p' ]
		end

		it "writes the credentials to a file" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@wrapper.stub!(:credentials_file).and_return(sandbox)
			@wrapper.stub!(:credentials).and_return(['one', 'two'])
			@wrapper.should_receive(:set_credentials_permissions)
			@wrapper.write_credentials
			File.read(sandbox).should == "one\ntwo\n"
		end

		it "sets ~/.heroku/credentials to be readable only by the user" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			FileUtils.mkdir_p(sandbox)
			fname = "#{sandbox}/file"
			system "touch #{fname}"
			@wrapper.stub!(:credentials_file).and_return(fname)
			@wrapper.set_credentials_permissions
			File.stat(sandbox).mode.should == 040700
			File.stat(fname).mode.should == 0100600
		end

		it "writes credentials and uploads authkey when credentials are saved" do
			@wrapper.stub!(:credentials)
			@wrapper.should_receive(:write_credentials)
			@wrapper.should_receive(:add_key)
			@wrapper.save_credentials
		end

		it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
			@wrapper.stub!(:write_credentials)
			@wrapper.stub!(:retry_login?).and_return(false)
			@wrapper.should_receive(:add_key).and_raise(RestClient::Unauthorized)
			@wrapper.should_receive(:delete_credentials)
			lambda { @wrapper.save_credentials }.should raise_error(RestClient::Unauthorized)
		end

		it "save_credentials deletes the credentials when there's no authkey" do
			@wrapper.stub!(:write_credentials)
			@wrapper.should_receive(:add_key).and_raise(RuntimeError)
			@wrapper.should_receive(:delete_credentials)
			lambda { @wrapper.save_credentials }.should raise_error
		end

		it "save_credentials deletes the credentials when the authkey is weak" do
			@wrapper.stub!(:write_credentials)
			@wrapper.should_receive(:add_key).and_raise(RestClient::RequestFailed)
			@wrapper.should_receive(:delete_credentials)
			lambda { @wrapper.save_credentials }.should raise_error
		end

		it "asks for login again when not authorized, for three times" do
			@wrapper.stub!(:write_credentials)
			@wrapper.stub!(:delete_credentials)
			@wrapper.stub!(:add_key).and_raise(RestClient::Unauthorized)
			@wrapper.should_receive(:ask_for_credentials).exactly(4).times
			lambda { @wrapper.save_credentials }.should raise_error(RestClient::Unauthorized)
		end

		it "deletes the credentials file" do
			FileUtils.should_receive(:rm_f).with(@wrapper.credentials_file)
			@wrapper.delete_credentials
		end
	end

	describe "key management" do
		it "finds the user's ssh key in ~/ssh/id_rsa.pub" do
			@wrapper.stub!(:home_directory).and_return('/home/joe')
			File.should_receive(:exists?).with('/home/joe/.ssh/id_rsa.pub').and_return(true)
			@wrapper.find_key.should == '/home/joe/.ssh/id_rsa.pub'
		end

		it "finds the user's ssh key in ~/ssh/id_dsa.pub" do
			@wrapper.stub!(:home_directory).and_return('/home/joe')
			File.should_receive(:exists?).with('/home/joe/.ssh/id_rsa.pub').and_return(false)
			File.should_receive(:exists?).with('/home/joe/.ssh/id_dsa.pub').and_return(true)
			@wrapper.find_key.should == '/home/joe/.ssh/id_dsa.pub'
		end

		it "raises an exception if neither id_rsa or id_dsa were found" do
			@wrapper.stub!(:home_directory).and_return('/home/joe')
			File.stub!(:exists?).and_return(false)
			lambda { @wrapper.find_key }.should raise_error(Heroku::CommandLine::UserError)
		end
	end

	describe "deprecated key management" do
		it "gets pub keys from the user's home directory" do
			@wrapper.should_receive(:home_directory).and_return('/Users/joe')
			File.should_receive(:exists?).with('/Users/joe/.ssh/id_xyz.pub').and_return(true)
			File.should_receive(:read).with('/Users/joe/.ssh/id_xyz.pub').and_return('ssh-xyz somehexkey')
			@wrapper.authkey_type('xyz').should == 'ssh-xyz somehexkey'
		end

		it "gets the rsa key" do
			@wrapper.stub!(:authkey_type).with('rsa').and_return('ssh-rsa somehexkey')
			@wrapper.authkey.should == 'ssh-rsa somehexkey'
		end

		it "gets the dsa key when there's no rsa" do
			@wrapper.stub!(:authkey_type).with('rsa').and_return(nil)
			@wrapper.stub!(:authkey_type).with('dsa').and_return('ssh-dsa somehexkey')
			@wrapper.authkey.should == 'ssh-dsa somehexkey'
		end

		it "raises a friendly error message when no key is found" do
			@wrapper.stub!(:authkey_type).with('rsa').and_return(nil)
			@wrapper.stub!(:authkey_type).with('dsa').and_return(nil)
			lambda { @wrapper.authkey }.should raise_error
		end

		it "accepts a custom key via the -k parameter" do
			Object.redefine_const(:ARGV, ['-k', '/Users/joe/sshkeys/mykey.pub'])
			@wrapper.should_receive(:authkey_read).with('/Users/joe/sshkeys/mykey.pub').and_return('ssh-rsa somehexkey')
			@wrapper.extract_key!
			@wrapper.authkey.should == 'ssh-rsa somehexkey'
		end

		it "extracts options from ARGV" do
			Object.redefine_const(:ARGV, %w( a b --something value c d ))
			@wrapper.extract_option(ARGV, '--something').should == 'value'
			ARGV.should == %w( a b c d )
		end

		it "rejects options outside valid values for ARGV" do
			Object.redefine_const(:ARGV, %w( -boolean_option t ))
			lambda { @wrapper.extract_argv_option('-boolean_option', %w( true false )) }.should raise_error
		end

		it "uploads the ssh authkey (deprecated in favor of add_key)" do
			@wrapper.should_receive(:extract_key!)
			@wrapper.should_receive(:authkey).and_return('my key')
			heroku = mock("heroku client")
			@wrapper.should_receive(:init_heroku).and_return(heroku)
			heroku.should_receive(:add_key).with('my key')
			@wrapper.upload_authkey
		end

		it "gets the home directory from HOME when running on *nix" do
			ENV.should_receive(:[]).with('HOME').and_return(@home)
			@wrapper.stub!(:running_on_windows?).and_return(false)
			@wrapper.home_directory.should == @home
		end

		it "gets the home directory from USERPROFILE when running on windows" do
			ENV.should_receive(:[]).with('USERPROFILE').and_return(@home)
			@wrapper.stub!(:running_on_windows?).and_return(true)
			@wrapper.home_directory.should == @home
		end

		it "detects it's running on windows" do
			Object.redefine_const(:RUBY_PLATFORM, 'i386-mswin32')
			@wrapper.should be_running_on_windows
		end

		it "doesn't consider cygwin as windows" do
			Object.redefine_const(:RUBY_PLATFORM, 'i386-cygwin')
			@wrapper.should_not be_running_on_windows
		end
	end

	describe "execute" do
		it "executes an action" do
			@wrapper.should_receive(:my_action).with(%w(arg1 arg2))
			@wrapper.execute('my_action', %w(arg1 arg2))
		end

		it "catches unauthorized errors" do
			@wrapper.should_receive(:my_action).and_raise(RestClient::Unauthorized)
			@wrapper.should_receive(:display).with('Authentication failure')
			@wrapper.execute('my_action', 'args')
		end

		it "parses rails-format error xml" do
			@wrapper.parse_error_xml('<errors><error>Error 1</error><error>Error 2</error></errors>').should == 'Error 1 / Error 2'
		end

		it "does not catch general exceptions, those are shown to the user as normal" do
			@wrapper.should_receive(:my_action).and_raise(RuntimeError)
			lambda { @wrapper.execute('my_action', 'args') }.should raise_error(RuntimeError)
		end
	end

	describe "app actions" do
		before do
			@wrapper.instance_variable_set('@credentials', %w(user pass))
		end

		it "shows app info" do
			@wrapper.heroku.should_receive(:info).with('myapp').and_return({ :name => 'myapp', :collaborators => [] })
			@wrapper.heroku.stub!(:domain).and_return('heroku.com')
			@wrapper.should_receive(:display).with('=== myapp')
			@wrapper.should_receive(:display).with('Web URL:        http://myapp.heroku.com/')
			@wrapper.info([ 'myapp' ])
		end

		it "creates without a name" do
			@wrapper.heroku.should_receive(:create).with(nil, {}).and_return("untitled-123")
			@wrapper.create([])
		end

		it "creates with a name" do
			@wrapper.heroku.should_receive(:create).with('myapp', {}).and_return("myapp")
			@wrapper.create([ 'myapp' ])
		end

		it "updates app" do
			@wrapper.heroku.should_receive(:update).with('myapp', { :name => 'myapp2', :share_public => true, :production => true })
			@wrapper.update([ 'myapp', '--name', 'myapp2', '--public', 'true', '--mode', 'production' ])
		end

		it "clones the app (deprecated in favor of straight git clone)" do
			@wrapper.should_receive(:system).with('git clone git@heroku.com:myapp.git')
			@wrapper.clone([ 'myapp' ])
		end
	end

	describe "collaborators" do
		before do
			@wrapper.instance_variable_set('@credentials', %w(user pass))
		end

		it "list collaborators when there's just the app name" do
			@wrapper.heroku.should_receive(:list_collaborators).and_return([])
			@wrapper.collaborators(['myapp'])
		end

		it "add collaborators with default access to view only" do
			@wrapper.heroku.should_receive(:add_collaborator).with('myapp', 'joe@example.com', 'view')
			@wrapper.collaborators(['myapp', '--add', 'joe@example.com'])
		end

		it "add collaborators with edit access" do
			@wrapper.heroku.should_receive(:add_collaborator).with('myapp', 'joe@example.com', 'edit')
			@wrapper.collaborators(['myapp', '--add', 'joe@example.com', '--access', 'edit'])
		end

		it "updates collaborators" do
			@wrapper.heroku.should_receive(:update_collaborator).with('myapp', 'joe@example.com', 'view')
			@wrapper.collaborators(['myapp', '--update', 'joe@example.com', '--access', 'view'])
		end

		it "removes collaborators" do
			@wrapper.heroku.should_receive(:remove_collaborator).with('myapp', 'joe@example.com')
			@wrapper.collaborators(['myapp', '--remove', 'joe@example.com'])
		end
	end
end
