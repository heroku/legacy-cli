require "spec_helper"
require "heroku/command/addons"

module Heroku::Command
  describe Addons do
    before do
      @addons = prepare_command(Addons)
      @addons.heroku.stub!(:releases).and_raise(RestClient::RequestFailed.new) # stub as if Releases not enabled
    end

    before do
      stub_core.releases("myapp").returns([ "name" => "v99" ])
    end

    describe "index" do
      context "when working with addons" do
        it "lists installed addons" do
          @addons.heroku.should_receive(:installed_addons).with('myapp').and_return([])
          @addons.index
        end
      end
      context "when workign with addons and attachments" do
        it "should list attachments" do
          c = [{"configured"=>true, "name"=>"heroku-postgresql:ronin", "attachment_name"=>"HEROKU_POSTGRESQL_RED"}]
          @addons.heroku.should_receive(:installed_addons).with('myapp').and_return(c)
          @addons.should_receive(:display).with("heroku-postgresql:ronin => HEROKU_POSTGRESQL_RED")
          @addons.index
        end
      end
    end

    describe 'adding' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "requires an addon name" do
        @addons.stub!(:args).and_return([])
        lambda { @addons.add }.should raise_error(CommandFailed)
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

      it "adds an addon with a price" do
        stub_core.install_addon("myapp", "my_addon", {}).returns({ "price" => "free" })
        execute "addons:add my_addon"
        output.should =~ /\(free\)/
      end

      it "adds an addon with a price and message" do
        stub_core.install_addon("myapp", "my_addon", {}).returns({ "price" => "free", "message" => "foo" })
        execute "addons:add my_addon"
        output.should == <<-OUTPUT.undent
          -----> Adding my_addon to myapp... done, v99 (free)
                 foo
        OUTPUT
      end

      it "adds an addon with a price and multiline message" do
        stub_core.install_addon("myapp", "my_addon", {}).returns({ "price" => "$200/mo", "message" => "foo\nbar" })
        execute "addons:add my_addon"
        output.should == <<-OUTPUT.undent
          -----> Adding my_addon to myapp... done, v99 ($200/mo)
                 foo
                 bar
        OUTPUT
      end
    end

    describe 'upgrading' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "requires an addon name" do
        @addons.stub!(:args).and_return([])
        lambda { @addons.upgrade }.should raise_error(CommandFailed)
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

      it "adds an addon with a price" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free" })
        execute "addons:upgrade my_addon"
        output.should == <<-OUTPUT.undent
          -----> Upgrading my_addon to myapp... done, v99 (free)
        OUTPUT
      end

      it "adds an addon with a price and message" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        execute "addons:upgrade my_addon"
        output.should == <<-OUTPUT.undent
          -----> Upgrading my_addon to myapp... done, v99 (free)
                 Don't Panic
        OUTPUT
      end
    end

    describe 'downgrading' do
      before { @addons.stub!(:args).and_return(%w(my_addon)) }

      it "requires an addon name" do
        @addons.stub!(:args).and_return([])
        lambda { @addons.downgrade }.should raise_error(CommandFailed)
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

      it "downgrades an addon with a price" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free" })
        execute "addons:downgrade my_addon"
        output.should == <<-OUTPUT.undent
          -----> Upgrading my_addon to myapp... done, v99 (free)
        OUTPUT
      end

      it "downgrades an addon with a price and message" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        execute "addons:downgrade my_addon"
        output.should == <<-OUTPUT.undent
          -----> Upgrading my_addon to myapp... done, v99 (free)
                 Don't Panic
        OUTPUT
      end
    end

    it "asks the user to confirm billing when API responds with 402" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      e = RestClient::RequestFailed.new
      e.stub!(:http_code).and_return(402)
      e.stub!(:http_body).and_return('{error:"test"}')
      @addons.heroku.should_receive(:install_addon).and_raise(e)
      @addons.should_receive(:confirm_billing).and_return(false)
      lambda { @addons.add }.should raise_error(SystemExit)
    end

    it "removes addons" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      @addons.heroku.should_receive(:uninstall_addon).with('myapp', 'addon1', :confirm => nil)
      @addons.remove
    end

    it "removes addons with confirmation when provided" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      @addons.stub!(:options).and_return(:confirm => "myapp")
      @addons.heroku.should_receive(:uninstall_addon).with('myapp', 'addon1', :confirm => "myapp")
      @addons.remove
    end

    describe "opening an addon" do
      before(:each) { @addons.stub!(:args).and_return(["red"]) }

      it "opens the addon if only one matches" do
        @addons.heroku.should_receive(:installed_addons).with("myapp").and_return([
          { "name" => "redistogo:basic" }
        ])
        Launchy.should_receive(:open).with("https://api.#{@addons.heroku.host}/myapps/myapp/addons/redistogo:basic")
        @addons.open
      end

      it "complains about ambiguity" do
        @addons.heroku.should_receive(:installed_addons).with("myapp").and_return([
          { "name" => "redistogo:basic" },
          { "name" => "red:color" }
        ])
        @addons.should_receive(:error).with("Ambiguous addon name: red")
        @addons.open
      end

      it "complains if nothing matches" do
        @addons.heroku.should_receive(:installed_addons).with("myapp").and_return([
          { "name" => "newrelic:bronze" }
        ])
        @addons.should_receive(:error).with("Unknown addon: red")
        @addons.open
      end
    end
  end
end
