require File.dirname(__FILE__) + '/base'

describe Wrapper do
	context "credentials check" do
		before do
			@wrapper = Wrapper.new
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
			@wrapper.should_receive(:ask_for_credentials)
			@wrapper.get_credentials
		end

		it "saves the credentials to a file" do
			sandbox = "/tmp/wrapper_spec_#{Process.pid}"
			FileUtils.rm_rf(sandbox)
			@wrapper.stub!(:credentials_file).and_return(sandbox)
			@wrapper.save_credentials('one', 'two')
			File.read(sandbox).should == "one\ntwo\n"
		end
	end

	context "actions" do
		before do
			@wrapper = Wrapper.new
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

		it "import -> create a new app from the local rails dir with a specified name" do
			orig_dir = Dir.pwd
			sandbox_dir = "/tmp/api_wrapper_spec.#{Process.pid}"
			begin
				FileUtils.rm_rf(sandbox_dir)
				system "rails #{sandbox_dir} > /dev/null"
				system "touch #{sandbox_dir}/imported"

				Dir.chdir(sandbox_dir)

				@wrapper.heroku.should_receive(:create).with('imported').and_return('imported')
				@wrapper.heroku.should_receive(:import)

				@wrapper.import([ 'imported' ])

				File.read("#{sandbox_dir}/config/heroku.yml").should match(/name: imported/)
			ensure
				FileUtils.rm_rf(sandbox_dir)
				Dir.chdir(orig_dir)
			end
		end
	end
end
