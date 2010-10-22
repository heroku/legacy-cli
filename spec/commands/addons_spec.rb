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

    describe 'adding' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "adds an addon with a price" do
        @addons.heroku.should_receive(:install_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free' })

        lambda { @addons.add }.
          should display_message(@addons, "done (free)")
      end

      it "adds an addon with a price and message" do
        @addons.heroku.should_receive(:install_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free', 'message' => "Don't Panic" })

        lambda { @addons.add }.
          should display_message(@addons, "done (free)\n  Don't Panic")
      end
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

    describe 'upgrading' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "adds an addon with a price" do
        @addons.heroku.should_receive(:upgrade_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free' })

        lambda { @addons.upgrade }.
          should display_message(@addons, "done (free)")
      end

      it "adds an addon with a price and message" do
        @addons.heroku.should_receive(:upgrade_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free', 'message' => "Don't Panic" })

        lambda { @addons.upgrade }.
          should display_message(@addons, "done (free)\n  Don't Panic")
      end
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

    describe 'downgrading' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "adds an addon with a price" do
        @addons.heroku.should_receive(:upgrade_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free' })

        lambda { @addons.downgrade }.
          should display_message(@addons, "done (free)")
      end

      it "adds an addon with a price and message" do
        @addons.heroku.should_receive(:upgrade_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free', 'message' => "Don't Panic" })

        lambda { @addons.downgrade }.
          should display_message(@addons, "done (free)\n  Don't Panic")
      end
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
