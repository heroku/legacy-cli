require File.dirname(__FILE__) + '/base'

describe Heroku::Command do
	it "extracts error messages from response when available in XML" do
		Heroku::Command.extract_error('<errors><error>Invalid app name</error></errors>').should == ' !   Invalid app name'
	end

	it "extracts error messages from response when available in JSON" do
		Heroku::Command.extract_error("{\"error\":\"Invalid app name\"}").should == ' !   Invalid app name'
	end

	it "shows Internal Server Error when the response doesn't contain a XML" do
		Heroku::Command.extract_error('<h1>HTTP 500</h1>').should == ' !   Internal server error'
	end
end