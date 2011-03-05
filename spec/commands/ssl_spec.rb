require File.expand_path("../base", File.dirname(__FILE__))

module Salesforce::Command
  describe Ssl do
    before do
      @ssl = prepare_command(Ssl)
    end

    it "adds ssl certificates to domains" do
      @ssl.stub!(:args).and_return(['my.crt', 'my.key'])
      File.should_receive(:exists?).with('my.crt').and_return(true)
      File.should_receive(:read).with('my.crt').and_return('crt contents')
      File.should_receive(:exists?).with('my.key').and_return(true)
      File.should_receive(:read).with('my.key').and_return('key contents')
      @ssl.salesforce.should_receive(:add_ssl).with('myapp', 'crt contents', 'key contents').and_return({})
      @ssl.add
    end

    it "removes certificates" do
      @ssl.stub!(:args).and_return(['example.com'])
      @ssl.salesforce.should_receive(:remove_ssl).with('myapp', 'example.com')
      @ssl.remove
    end
  end
end
