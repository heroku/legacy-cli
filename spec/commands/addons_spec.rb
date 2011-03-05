require File.expand_path("../base", File.dirname(__FILE__))

module Salesforce::Command
  describe Addons do
    before do
      @addons = prepare_command(Addons)
    end

    describe "index" do
      context "when working with addons" do
        it "lists installed addons" do
          @addons.salesforce.should_receive(:installed_addons).with('myapp').and_return([])
          @addons.index
        end
      end
      context "when workign with addons and attachments" do
        it "should list attachments" do
          c = [{"configured"=>true, "name"=>"salesforce-postgresql:ronin", "attachment_name"=>"SALESFORCE_POSTGRESQL_RED"}]
          @addons.salesforce.should_receive(:installed_addons).with('myapp').and_return(c)
          @addons.should_receive(:display).with("salesforce-postgresql:ronin => SALESFORCE_POSTGRESQL_RED")
          @addons.index
        end
      end
    end

    it "adds an addon" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.salesforce.should_receive(:install_addon).with('myapp', 'my_addon', {})
      @addons.add
    end

    it "adds an addon with config vars" do
      @addons.stub!(:args).and_return(%w(my_addon foo=baz))
      @addons.salesforce.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
      @addons.add
    end

    describe 'adding' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "adds an addon with a price" do
        @addons.salesforce.should_receive(:install_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free' })

        lambda { @addons.add }.
          should display_message(@addons, "done (free)")
      end

      it "adds an addon with a price and message" do
        @addons.salesforce.should_receive(:install_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free', 'message' => "Don't Panic" })

        lambda { @addons.add }.
          should display_message(@addons, "done (free)\n  Don't Panic")
      end
    end

    it "upgrades an addon" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.salesforce.should_receive(:upgrade_addon).with('myapp', 'my_addon', {})
      @addons.upgrade
    end

    it "upgrade an addon with config vars" do
      @addons.stub!(:args).and_return(%w(my_addon foo=baz))
      @addons.salesforce.should_receive(:upgrade_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
      @addons.upgrade
    end

    describe 'upgrading' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "adds an addon with a price" do
        @addons.salesforce.should_receive(:upgrade_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free' })

        lambda { @addons.upgrade }.
          should display_message(@addons, "done (free)")
      end

      it "adds an addon with a price and message" do
        @addons.salesforce.should_receive(:upgrade_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free', 'message' => "Don't Panic" })

        lambda { @addons.upgrade }.
          should display_message(@addons, "done (free)\n  Don't Panic")
      end
    end

    it "downgrades an addon" do
      @addons.stub!(:args).and_return(%w(my_addon))
      @addons.salesforce.should_receive(:upgrade_addon).with('myapp', 'my_addon', {})
      @addons.downgrade
    end

    it "downgrade an addon with config vars" do
      @addons.stub!(:args).and_return(%w(my_addon foo=baz))
      @addons.salesforce.should_receive(:upgrade_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
      @addons.downgrade
    end

    describe 'downgrading' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "adds an addon with a price" do
        @addons.salesforce.should_receive(:upgrade_addon).
          with('myapp', 'my_addon', {}).
          and_return({ 'price' => 'free' })

        lambda { @addons.downgrade }.
          should display_message(@addons, "done (free)")
      end

      it "adds an addon with a price and message" do
        @addons.salesforce.should_receive(:upgrade_addon).
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
      @addons.salesforce.should_receive(:install_addon).and_raise(e)
      @addons.should_receive(:confirm_billing).and_return(false)
      @addons.add
    end

    it "removes addons" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      @addons.salesforce.should_receive(:uninstall_addon).with('myapp', 'addon1')
      @addons.remove
    end

    it "clears addons" do
      @addons.salesforce.should_receive(:installed_addons).with('myapp').and_return([{ 'name' => 'addon1' }])
      @addons.salesforce.should_receive(:uninstall_addon).with('myapp', 'addon1')
      @addons.clear
    end

    it "doesn't remove shared database" do
      @addons.salesforce.should_receive(:installed_addons).with('myapp').and_return([{ 'name' => 'shared-database:5mb'}])
      @addons.salesforce.should_not_receive(:uninstall_addon).with('myapp', 'shared-database:5mb')
      @addons.clear
    end

    describe "opening an addon" do
      before(:each) { @addons.stub!(:args).and_return(["red"]) }

      it "opens the addon if only one matches" do
        @addons.salesforce.should_receive(:installed_addons).with("myapp").and_return([
          { "name" => "redistogo:basic" }
        ])
        Launchy.should_receive(:open).with("https://api.#{@addons.salesforce.host}/myapps/myapp/addons/redistogo:basic")
        @addons.open
      end

      it "complains about ambiguity" do
        @addons.salesforce.should_receive(:installed_addons).with("myapp").and_return([
          { "name" => "redistogo:basic" },
          { "name" => "red:color" }
        ])
        @addons.should_receive(:error).with("Ambiguous addon name: red")
        @addons.open
      end

      it "complains if nothing matches" do
        @addons.salesforce.should_receive(:installed_addons).with("myapp").and_return([
          { "name" => "newrelic:bronze" }
        ])
        @addons.should_receive(:error).with("Unknown addon: red")
        @addons.open
      end
    end
  end
end
