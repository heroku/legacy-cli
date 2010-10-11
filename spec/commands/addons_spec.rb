require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Addons do
    before do
      @addons = prepare_command(Addons)
    end

    it "index lists installed addons" do
      @addons.heroku.should_receive(:installed_addons).with('myapp').and_return([])
      @addons.index
    end

    it "adds an addon" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', {})
      @addons.add
    end

    it "adds an addon with config vars" do
      @addons.stub!(:args).and_return(%w(my_addon foo=baz))
      @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
      @addons.add
    end

    it "adds an addon with a response message" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.heroku.should_receive(:install_addon).
        with('myapp', 'my_addon', {}).
        and_return("Don't Panic")

      received_message = false
      @addons.should_receive(:display).any_number_of_times do |message, newline|
        received_message = received_message || message == "done Don't Panic"
      end

      @addons.add

      received_message.should be_true,
        'expected addon install message to be printed'
    end

    it "upgrades an addon" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.heroku.should_receive(:upgrade_addon).with('myapp', 'my_addon', {})
      @addons.upgrade
    end

    it "upgrade an addon with config vars" do
      @addons.stub!(:args).and_return(%w(my_addon foo=baz))
      @addons.heroku.should_receive(:upgrade_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
      @addons.upgrade
    end

    it "upgrades an addon with a response message" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.heroku.should_receive(:upgrade_addon).
        with('myapp', 'my_addon', {}).
        and_return("Don't Panic")

      received_message = false
      @addons.should_receive(:display).any_number_of_times do |message, newline|
        received_message = received_message || message == "done Don't Panic"
      end

      @addons.upgrade

      received_message.should be_true,
        'expected addon upgrade message to be printed'
    end

    it "downgrades an addon" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.heroku.should_receive(:upgrade_addon).with('myapp', 'my_addon', {})
      @addons.downgrade
    end

    it "downgrade an addon with config vars" do
      @addons.stub!(:args).and_return(%w(my_addon foo=baz))
      @addons.heroku.should_receive(:upgrade_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
      @addons.downgrade
    end

    it "downgrades an addon with a response message" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.heroku.should_receive(:upgrade_addon).
        with('myapp', 'my_addon', {}).
        and_return("Don't Panic")

      received_message = false
      @addons.should_receive(:display).any_number_of_times do |message, newline|
        received_message = received_message || message == "done Don't Panic"
      end

      @addons.downgrade

      received_message.should be_true,
        'expected addon downgrade message to be printed'
    end

    it "asks the user to confirm billing when API responds with 402" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      e = RestClient::RequestFailed.new
      e.stub!(:http_code).and_return(402)
      e.stub!(:http_body).and_return('{error:"test"}')
      @addons.heroku.should_receive(:install_addon).and_raise(e)
      @addons.should_receive(:confirm_billing).and_return(false)
      @addons.add
    end

    it "removes addons" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      @addons.heroku.should_receive(:uninstall_addon).with('myapp', 'addon1')
      @addons.remove
    end

    it "clears addons" do
      @addons.heroku.should_receive(:installed_addons).with('myapp').and_return([{ 'name' => 'addon1' }])
      @addons.heroku.should_receive(:uninstall_addon).with('myapp', 'addon1')
      @addons.clear
    end
  end
end
