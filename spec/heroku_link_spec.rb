require File.dirname(__FILE__) + '/base'

describe HerokuLink do
	before(:each) do
		@client = HerokuLink.new
	end

	it "list -> get a list of this user's apps" do
		@client.should_receive(:transmit).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<apps type="array">
	<app><name>myapp1</name></app>
	<app><name>myapp2</name></app>
</apps>
EOXML
		@client.list.should == %w(myapp1 myapp2)
	end

	it "create -> create a new blank app" do
		@client.should_receive(:transmit).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<app><name>untitled-123</name></app>
EOXML
		@client.create.should == "untitled-123"
	end

	it "create(name) -> create a new blank app with a specified name" do
		@client.should_receive(:post).with("/apps?app[name]=newapp").and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<app><name>newapp</name></app>
EOXML
		@client.create("newapp").should == "newapp"
	end

	it "destroy(name) -> destroy the named app" do
		@client.should_receive(:delete).with("/apps/destroyme")
		@client.destroy("destroyme")
	end

	it "import(name, archive) -> upload an archive of a rails dir to replace a named app" do
		@client.should_receive(:transmit) do |req, payload|
			req.path.should == "/apps/myapp"
			req.content_type.should == "application/x-gtar"
			payload.should == "archive"
		end
		@client.import("myapp", "archive")
	end

	it "export(name) -> download an archive of the app" do
		@client.should_receive(:transmit) do |req, payload|
			req.path.should == "/apps/myapp"
			req.to_hash['accept'].first.should == "application/x-gtar"
		end
		@client.export("myapp")
	end

	it "reads username and password from the credentials file" do
		sandbox = "/tmp/client_spec.#{Process.pid}/credentials"
		FileUtils.rm_rf(File.dirname(sandbox))
		FileUtils.mkdir_p(File.dirname(sandbox))
		File.open(sandbox, "w") { |f| f.write "user\npass\n" }
		@client.stub!(:credentials_file).and_return(sandbox)
		@client.credentials.should == %w(user pass)
		@client.user.should == 'user'
		@client.password.should == 'pass'
	end

	it "asks for credentials when the file doesn't exist" do
		sandbox = "/tmp/client_spec.#{Process.pid}/credentials"
		FileUtils.rm_rf(File.dirname(sandbox))
		@client.stub!(:credentials_file).and_return(sandbox)
		@client.should_receive(:ask_for_credentials)
		@client.credentials
	end

	it "saves the credentials to a file" do
		sandbox = "/tmp/client_spec.#{Process.pid}/credentials"
		FileUtils.rm_rf(File.dirname(sandbox))
		@client.stub!(:credentials_file).and_return(sandbox)
		@client.save_credentials('one', 'two')
		File.read(sandbox).should == "one\ntwo\n"
	end
end
