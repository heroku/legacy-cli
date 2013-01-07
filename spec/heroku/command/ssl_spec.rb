require "spec_helper"
require "heroku/command/ssl"

module Heroku::Command
  describe Ssl do

    it "adds ssl certificates to domains" do
      File.should_receive(:exists?).with('.git').and_return(false)
      File.should_receive(:exists?).with('my.crt').and_return(true)
      File.should_receive(:read).with('my.crt').and_return('crt contents')
      File.should_receive(:exists?).with('my.key').and_return(true)
      File.should_receive(:read).with('my.key').and_return('key contents')
      expires_at = Time.now + 60 * 60 * 24 * 365
      stub_core.add_ssl('example', 'crt contents', 'key contents').returns({"domain" => "example.com", "expires_at" => expires_at})
      stderr, stdout = execute("ssl:add my.crt my.key")
      stderr.should == ""
      stdout.should == <<-STDOUT
Added certificate to example.com, expiring at #{expires_at}
STDOUT
    end

    it "removes certificates" do
      stub_core.remove_ssl('example', 'example.com')
      stderr, stdout = execute("ssl:remove example.com")
      stderr.should == ""
      stdout.should == <<-STDOUT
Removed certificate from example.com
STDOUT
    end

  end
end
