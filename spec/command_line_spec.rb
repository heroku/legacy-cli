require File.dirname(__FILE__) + '/base'

describe Heroku::CommandLine do
	before do
		@cli = Heroku::CommandLine.new
		@cli.stub!(:display)
		@cli.stub!(:print)
		@cli.stub!(:heroku).and_return(mock('heroku client', :host => 'heroku.com'))
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
			@cli.should_receive(:keys_add)
			@cli.save_credentials
		end

		it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
			@cli.stub!(:write_credentials)
			@cli.stub!(:retry_login?).and_return(false)
			@cli.should_receive(:keys_add).and_raise(RestClient::Unauthorized)
			@cli.should_receive(:delete_credentials)
			lambda { @cli.save_credentials }.should raise_error(RestClient::Unauthorized)
		end

		it "save_credentials deletes the credentials when there's no authkey" do
			@cli.stub!(:write_credentials)
			@cli.should_receive(:keys_add).and_raise(RuntimeError)
			@cli.should_receive(:delete_credentials)
			lambda { @cli.save_credentials }.should raise_error
		end

		it "save_credentials deletes the credentials when the authkey is weak" do
			@cli.stub!(:write_credentials)
			@cli.should_receive(:keys_add).and_raise(RestClient::RequestFailed)
			@cli.should_receive(:delete_credentials)
			lambda { @cli.save_credentials }.should raise_error
		end

		it "asks for login again when not authorized, for three times" do
			@cli.stub!(:write_credentials)
			@cli.stub!(:delete_credentials)
			@cli.stub!(:keys_add).and_raise(RestClient::Unauthorized)
			@cli.should_receive(:ask_for_credentials).exactly(4).times
			lambda { @cli.save_credentials }.should raise_error(RestClient::Unauthorized)
		end

		it "deletes the credentials file" do
			FileUtils.should_receive(:rm_f).with(@cli.credentials_file)
			@cli.delete_credentials
		end
	end

	context "getting the app" do
		before do
			@cli.instance_variable_set('@credentials', %w(user pass))
			Dir.stub!(:pwd).and_return('/home/dev/myapp')
		end

		it "attempts to find the app via the --app argument" do
			@cli.extract_app(['--app', 'myapp']).should == 'myapp'
		end

		it "parses the app from git config when there's only one remote" do
			File.stub!(:exists?).with('/home/dev/myapp/.git/config').and_return(true)
			File.stub!(:read).with('/home/dev/myapp/.git/config').and_return("
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true
[remote \"heroku\"]
	url = git@heroku.com:myapp.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
			")
			@cli.extract_app([]).should == 'myapp'
		end

		it "uses the remote named after the current folder name when there are multiple" do
			File.stub!(:exists?).with('/home/dev/myapp/.git/config').and_return(true)
			File.stub!(:read).with('/home/dev/myapp/.git/config').and_return("
[remote \"heroku_backup\"]
	url = git@heroku.com:myapp-backup.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
[remote \"heroku\"]
	url = git@heroku.com:myapp.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
			")
			@cli.extract_app([]).should == 'myapp'
		end

		it "raises when cannot determine which app is it" do
			File.stub!(:exists?).with('/home/dev/myapp/.git/config').and_return(true)
			File.stub!(:read).with('/home/dev/myapp/.git/config').and_return("
[remote \"heroku_backup\"]
	url = git@heroku.com:app1.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
[remote \"heroku\"]
	url = git@heroku.com:app2.git
	fetch = +refs/heads/*:refs/remotes/heroku/*
			")
			lambda { @cli.extract_app([]).should }.should raise_error(Heroku::CommandLine::CommandFailed)
		end
	end

	describe "key management" do
		before do
			@cli.instance_variable_set('@credentials', %w(user pass))
		end

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
			lambda { @cli.find_key }.should raise_error(Heroku::CommandLine::CommandFailed)
		end

		it "adds a key from the default locations if no key filename is supplied" do
			@cli.should_receive(:find_key).and_return('/home/joe/.ssh/id_rsa.pub')
			File.should_receive(:read).with('/home/joe/.ssh/id_rsa.pub').and_return('ssh-rsa xyz')
			@cli.heroku.should_receive(:add_key).with('ssh-rsa xyz')
			@cli.keys_add([])
		end

		it "adds a key from a specified keyfile path" do
			@cli.should_not_receive(:find_key)
			File.should_receive(:read).with('/my/key.pub').and_return('ssh-rsa xyz')
			@cli.heroku.should_receive(:add_key).with('ssh-rsa xyz')
			@cli.keys_add(['/my/key.pub'])
		end

		it "list keys, trimming the hex code for better display" do
			@cli.heroku.should_receive(:keys).and_return(["ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku\n"])
			@cli.should_receive(:display).with('ssh-rsa AAAAB3NzaC...Fyoke4MQ== pedro@heroku')
			@cli.keys([])
		end

		it "shows the whole key hex with --long" do
			@cli.heroku.should_receive(:keys).and_return(["ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku\n"])
			@cli.should_receive(:display).with("ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku")
			@cli.keys(['--long'])
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

		it "uploads the ssh authkey (deprecated in favor of keys_add)" do
			@cli.should_receive(:extract_key!)
			@cli.should_receive(:authkey).and_return('my key')
			@cli.heroku.should_receive(:add_key).with('my key')
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
			@cli.stub!(:extract_app_in_dir).and_return('myapp')
		end

		it "shows app info, converting bytes to kbs/mbs" do
			@cli.heroku.should_receive(:info).with('myapp').and_return({ :name => 'myapp', :collaborators => [], :code_size => 2*1024, :data_size => 5*1024*1024 })
			@cli.should_receive(:display).with('=== myapp')
			@cli.should_receive(:display).with('Web URL:        http://myapp.heroku.com/')
			@cli.should_receive(:display).with('Code size:      2k')
			@cli.should_receive(:display).with('Data size:      5M')
			@cli.info([])
		end

		it "creates without a name" do
			@cli.heroku.should_receive(:create).with(nil, {}).and_return("untitled-123")
			@cli.create([])
		end

		it "creates with a name" do
			@cli.heroku.should_receive(:create).with('myapp', {}).and_return("myapp")
			@cli.create([ 'myapp' ])
		end

		it "renames an app" do
			@cli.heroku.should_receive(:update).with('myapp', { :name => 'myapp2' })
			@cli.rename([ 'myapp2' ])
		end

		it "clones the app (deprecated in favor of straight git clone)" do
			@cli.should_receive(:system).with('git clone git@heroku.com:myapp.git')
			@cli.clone([])
		end

		it "runs a rake command on the app" do
			@cli.heroku.should_receive(:rake).with('myapp', 'db:migrate')
			@cli.rake([ 'db:migrate' ])
		end

		it "runs a single console command on the app" do
			@cli.heroku.should_receive(:console).with('myapp', '2+2')
			@cli.console([ '2+2' ])
		end

		it "offers a console, opening and closing the session with the client" do
			@console = mock('heroku console')
			@cli.heroku.should_receive(:console).with('myapp').and_yield(@console)
			Readline.should_receive(:readline).and_return('exit')
			@cli.console([])
		end

		it "asks to restart servers" do
			@cli.heroku.should_receive(:restart).with('myapp')
			@cli.restart([])
		end

		it "shows the app logs" do
			@cli.heroku.should_receive(:logs).with('myapp').and_return('logs')
			@cli.should_receive(:display).with('logs')
			@cli.logs([])
		end
	end

	describe "collaborators" do
		before do
			@cli.instance_variable_set('@credentials', %w(user pass))
			@cli.stub!(:extract_app_in_dir).and_return('myapp')
		end

		it "lists collaborators" do
			@cli.heroku.should_receive(:list_collaborators).and_return([])
			@cli.sharing([])
		end

		it "adds collaborators with default access to view only" do
			@cli.heroku.should_receive(:add_collaborator).with('myapp', 'joe@example.com', 'view')
			@cli.sharing_add(['joe@example.com'])
		end

		it "add collaborators with edit access" do
			@cli.heroku.should_receive(:add_collaborator).with('myapp', 'joe@example.com', 'edit')
			@cli.sharing_add(['joe@example.com', '--access', 'edit'])
		end

		it "removes collaborators" do
			@cli.heroku.should_receive(:remove_collaborator).with('myapp', 'joe@example.com')
			@cli.sharing_remove(['joe@example.com'])
		end
	end

	describe "domain names" do
		before do
			@cli.instance_variable_set('@credentials', %w(user pass))
			@cli.stub!(:extract_app_in_dir).and_return('myapp')
		end

		it "lists domain" do
			@cli.heroku.should_receive(:list_domains).and_return([])
			@cli.domains([])
		end

		it "adds domain names" do
			@cli.heroku.should_receive(:add_domain).with('myapp', 'example.com')
			@cli.domains_add(['example.com'])
		end

		it "removes domain names" do
			@cli.heroku.should_receive(:remove_domain).with('myapp', 'example.com')
			@cli.domains_remove(['example.com'])
		end

		it "removes all domain names" do
			@cli.heroku.should_receive(:remove_domains).with('myapp')
			@cli.domains_clear([])
		end
	end

	describe "formatting" do
		it "formats app urls (http and git), displayed as output on create and other commands" do
			@cli.heroku.stub!(:host).and_return('example.com')
			@cli.app_urls('test').should == "http://test.example.com/ | git@example.com:test.git"
		end
	end
end
