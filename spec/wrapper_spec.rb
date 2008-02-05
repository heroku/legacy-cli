require File.dirname(__FILE__) + '/base'

describe Wrapper do
	before(:each) do
		@wrapper = Wrapper.new
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
