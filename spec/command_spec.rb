require File.expand_path("./base", File.dirname(__FILE__))

describe Heroku::Command do
  it "extracts error messages from response when available in XML" do
    Heroku::Command.extract_error('<errors><error>Invalid app name</error></errors>').should == ' !   Invalid app name'
  end

  it "extracts error messages from response when available in JSON" do
    Heroku::Command.extract_error("{\"error\":\"Invalid app name\"}").should == ' !   Invalid app name'
  end

  it "extracts error messages from response when available in JSON" do
    response = mock(:to_s => "Invalid app name", :headers => { :content_type => "text/plain; charset=UTF8" })
    Heroku::Command.extract_error(response).should == ' !   Invalid app name'
  end

  it "shows Internal Server Error when the response doesn't contain a XML or JSON" do
    Heroku::Command.extract_error('<h1>HTTP 500</h1>').should == ' !   Internal server error'
  end

  it "shows Internal Server Error when the response is not plain text" do
    response = mock(:to_s => "Foobar", :headers => { :content_type => "application/xml" })
    Heroku::Command.extract_error(response).should == ' !   Internal server error'
  end

  it "handles a nil body in parse_error_xml" do
    lambda { Heroku::Command.parse_error_xml(nil) }.should_not raise_error
  end

  it "handles a nil body in parse_error_json" do
    lambda { Heroku::Command.parse_error_json(nil) }.should_not raise_error
  end

  it "correctly resolves commands" do
    class Heroku::Command::Test; end
    class Heroku::Command::Test::Multiple; end

    Heroku::Command.parse("foo").should == [ Heroku::Command::App, :foo ]
    Heroku::Command.parse("test").should == [ Heroku::Command::Test, :index ]
    Heroku::Command.parse("test:foo").should == [ Heroku::Command::Test, :foo   ]
    Heroku::Command.parse("test:multiple:foo").should == [ Heroku::Command::Test::Multiple, :foo ]
  end
end