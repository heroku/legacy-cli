require File.expand_path("./base", File.dirname(__FILE__))

describe Salesforce::Command do
  it "extracts error messages from response when available in XML" do
    Salesforce::Command.extract_error('<errors><error>Invalid app name</error></errors>').should == ' !   Invalid app name'
  end

  it "extracts error messages from response when available in JSON" do
    Salesforce::Command.extract_error("{\"error\":\"Invalid app name\"}").should == ' !   Invalid app name'
  end

  it "extracts error messages from response when available in JSON" do
    response = mock(:to_s => "Invalid app name", :headers => { :content_type => "text/plain; charset=UTF8" })
    Salesforce::Command.extract_error(response).should == ' !   Invalid app name'
  end

  it "shows Internal Server Error when the response doesn't contain a XML or JSON" do
    Salesforce::Command.extract_error('<h1>HTTP 500</h1>').should == ' !   Internal server error'
  end

  it "shows Internal Server Error when the response is not plain text" do
    response = mock(:to_s => "Foobar", :headers => { :content_type => "application/xml" })
    Salesforce::Command.extract_error(response).should == ' !   Internal server error'
  end

  it "handles a nil body in parse_error_xml" do
    lambda { Salesforce::Command.parse_error_xml(nil) }.should_not raise_error
  end

  it "handles a nil body in parse_error_json" do
    lambda { Salesforce::Command.parse_error_json(nil) }.should_not raise_error
  end

  it "correctly resolves commands" do
    class Salesforce::Command::Test; end
    class Salesforce::Command::Test::Multiple; end

    Salesforce::Command.parse("foo").should == [ Salesforce::Command::App, :foo ]
    Salesforce::Command.parse("test").should == [ Salesforce::Command::Test, :index ]
    Salesforce::Command.parse("test:foo").should == [ Salesforce::Command::Test, :foo   ]
    Salesforce::Command.parse("test:multiple:foo").should == [ Salesforce::Command::Test::Multiple, :foo ]
  end
end
