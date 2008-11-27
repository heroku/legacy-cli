require File.dirname(__FILE__) + '/base'

describe Heroku::Command do
	it "extracts error messages from response when available in XML" do
		response = mock('response', :code => '422', :body => '<errors><error>Invalid app name</error></errors>')
		Heroku::Command.extract_error(response).should == 'Invalid app name'
	end

	it "shows Internal Server Error when the response doesn't contain a XML" do
		response = mock('response', :code => '500', :body => '<h1>HTTP 500</h1>')
		Heroku::Command.extract_error(response).should == 'Internal server error'
	end
end