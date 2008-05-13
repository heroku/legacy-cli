require File.dirname(__FILE__) + '/base'

describe Heroku::CommandLine do
	context "credentials" do
		before do
			@wrapper = Heroku::CommandLine.new
			@wrapper.stub!(:display)
			@wrapper.stub!(:print)
		end

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
			@wrapper.should_receive(:upload_authkey)
			@wrapper.save_credentials
		end

		it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
			@wrapper.stub!(:write_credentials)
			@wrapper.stub!(:retry_login?).and_return(false)
			@wrapper.should_receive(:upload_authkey).and_raise(Heroku::Client::Unauthorized)
			@wrapper.should_receive(:delete_credentials)
			lambda { @wrapper.save_credentials }.should raise_error(Heroku::Client::Unauthorized)
		end

		it "save_credentials deletes the credentials when there's no authkey" do
			@wrapper.stub!(:write_credentials)
			@wrapper.should_receive(:upload_authkey).and_raise(RuntimeError)
			@wrapper.should_receive(:delete_credentials)
			lambda { @wrapper.save_credentials }.should raise_error
		end

		it "asks for login again when not authorized, for three times" do
			@wrapper.stub!(:write_credentials)
			@wrapper.stub!(:upload_authkey).and_raise(Heroku::Client::Unauthorized)
			@wrapper.should_receive(:ask_for_credentials).exactly(4).times
			lambda { @wrapper.save_credentials }.should raise_error(Heroku::Client::Unauthorized)
		end

		it "deletes the credentials file" do
			FileUtils.should_receive(:rm_f).with(@wrapper.credentials_file)
			@wrapper.delete_credentials
		end

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

		it "uploads the ssh authkey" do
			@wrapper.should_receive(:authkey).and_return('my key')
			heroku = mock("heroku client")
			@wrapper.should_receive(:init_heroku).and_return(heroku)
			heroku.should_receive(:upload_authkey).with('my key')
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

	context "actions" do
		before do
			@wrapper = Heroku::CommandLine.new
			@wrapper.stub!(:display)
			@wrapper.instance_variable_set('@credentials', %w(user pass))
		end

		it "creates without a name" do
			@wrapper.heroku.should_receive(:create).with(nil).and_return("untitled-123")
			@wrapper.create([])
		end

		it "creates with a name" do
			@wrapper.heroku.should_receive(:create).with('myapp').and_return("myapp")
			@wrapper.create([ 'myapp' ])
		end
	end

	context "cloning the app" do
		before do
			@wrapper = Heroku::CommandLine.new
			@wrapper.stub!(:display)
			@wrapper.instance_variable_set('@credentials', %w(user pass))
			@wrapper.stub!(:system).and_return(true)
			@wrapper.stub!(:write_generic_database_yml)
			Dir.stub!(:mkdir)
			File.stub!(:directory?)
		end

		it "calls git clone" do
			@wrapper.should_receive(:system).with('git clone git@heroku.com:myapp.git').and_return(true)
			@wrapper.clone(['myapp'])
		end

		it "creates directories" do
			Dir.stub!(:pwd).and_return('/users/joe/dev')
			Dir.should_receive(:mkdir).with('/users/joe/dev/myapp/db')
			Dir.should_receive(:mkdir).with('/users/joe/dev/myapp/log')
			Dir.should_receive(:mkdir).with('/users/joe/dev/myapp/tmp')
			Dir.should_receive(:mkdir).with('/users/joe/dev/myapp/public')
			Dir.should_receive(:mkdir).with('/users/joe/dev/myapp/public/stylesheets')
			@wrapper.clone(['myapp'])
		end

		it "opens the folder and runs db:migrate on *nix" do
			@wrapper.stub!(:running_on_windows?).and_return(false)
			@wrapper.should_receive(:system).with('cd myapp;rake db:migrate')
			@wrapper.clone(['myapp'])
		end

		it "opens the folder and runs db:migrate on windows" do
			@wrapper.stub!(:running_on_windows?).and_return(true)
			@wrapper.should_receive(:system).with('cd myapp&&rake db:migrate')
			@wrapper.clone(['myapp'])
		end
	end
end
