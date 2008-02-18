require File.dirname(__FILE__) + '/base'

describe HerokuWrapper do
	context "credentials" do
		before do
			@wrapper = HerokuWrapper.new
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

		it "uploads the ssh authkey" do
			@wrapper.should_receive(:authkey).and_return('my key')
			@wrapper.heroku.should_receive(:upload_authkey).with('my key')
			@wrapper.upload_authkey
		end
	end

	context "actions" do
		before do
			@wrapper = HerokuWrapper.new
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
