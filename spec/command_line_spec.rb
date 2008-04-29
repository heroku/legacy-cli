require File.dirname(__FILE__) + '/base'

describe Heroku::CommandLine do
	context "credentials" do
		before do
			@wrapper = Heroku::CommandLine.new
			@wrapper.stub!(:display)
		end

		it "reads credentials from the credentials file" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			File.open(sandbox, "w") { |f| f.write "user\npass\n" }
			@wrapper.stub!(:credentials_file).and_return(sandbox)
			@wrapper.get_credentials.should == %w(user pass)
		end

		it "takes the user from the first line and the password from the second line" do
			@wrapper.stub!(:get_credentials).and_return(%w(user pass))
			@wrapper.user.should == 'user'
			@wrapper.password.should == 'pass'
		end

		it "asks for credentials when the file doesn't exist" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@wrapper.stub!(:credentials_file).and_return(sandbox)
			@wrapper.should_receive(:ask_for_credentials).and_return([ 'u', 'p'])
			@wrapper.should_receive(:save_credentials).with('u', 'p')
			@wrapper.get_credentials.should == [ 'u', 'p' ]
		end

		it "writes the credentials to a file" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@wrapper.stub!(:credentials_file).and_return(sandbox)
			@wrapper.write_credentials('one', 'two')
			File.read(sandbox).should == "one\ntwo\n"
		end

		it "writes credentials and uploads authkey when credentials are saved" do
			@wrapper.should_receive(:write_credentials).with('a', 'b')
			@wrapper.should_receive(:upload_authkey)
			@wrapper.save_credentials('a', 'b')
		end

		it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
			@wrapper.stub!(:write_credentials)
			@wrapper.should_receive(:upload_authkey).and_raise(Heroku::Client::Unauthorized)
			@wrapper.should_receive(:delete_credentials)
			lambda { @wrapper.save_credentials('a', 'b') }.should raise_error(Heroku::Client::Unauthorized)
		end

		it "deletes the credentials file" do
			FileUtils.should_receive(:rm_f).with(@wrapper.credentials_file)
			@wrapper.delete_credentials
		end

		it "gets the rsa key from the user's home directory" do
			ENV.should_receive(:[]).with('HOME').and_return('/Users/joe')
			File.should_receive(:exists?).with('/Users/joe/.ssh/id_rsa.pub').and_return(true)
			File.should_receive(:read).with('/Users/joe/.ssh/id_rsa.pub').and_return('ssh-rsa somehexkey')
			@wrapper.authkey.should == 'ssh-rsa somehexkey'
		end

		it "gets the dsa key when there's no rsa" do
			ENV.should_receive(:[]).at_least(:once).with('HOME').and_return('/Users/joe')
			File.should_receive(:exists?).with('/Users/joe/.ssh/id_rsa.pub').and_return(false)
			File.should_receive(:exists?).with('/Users/joe/.ssh/id_dsa.pub').and_return(true)
			File.should_receive(:read).with('/Users/joe/.ssh/id_dsa.pub').and_return('ssh-dsa somehexkey')
			@wrapper.authkey.should == 'ssh-dsa somehexkey'
		end

		it "raise a friendly error message when no key is found" do
			ENV.should_receive(:[]).at_least(:once).with('HOME').and_return('/Users/joe')
			lambda { @wrapper.authkey }.should raise_error
		end

		it "uploads the ssh authkey" do
			@wrapper.should_receive(:authkey).and_return('my key')
			heroku = mock("heroku client")
			@wrapper.should_receive(:init_heroku).and_return(heroku)
			heroku.should_receive(:upload_authkey).with('my key')
			@wrapper.upload_authkey
		end
	end

	context "actions" do
		before do
			@wrapper = Heroku::CommandLine.new
			@wrapper.stub!(:display)
			@wrapper.stub!(:get_credentials).and_return(%w(user pass))
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
end
