require "spec_helper"
require "heroku/command/addons"

module Heroku::Command
  describe Addons do
    before do
      @addons = prepare_command(Addons)
      stub_core.release("myapp", "current").returns( "name" => "v99" )
    end

    describe "index" do
      context "when working with addons" do
        it "lists installed addons" do
          stub_core.installed_addons('myapp').returns([])
          stderr, stdout = execute("addons")
          stderr.should == ""
          stdout.should == <<-STDOUT
No addons installed
STDOUT
        end
      end
      context "when working with addons and attachments" do
        it "should list attachments" do
          stub_core.installed_addons('myapp').returns([{"configured"=>true, "name"=>"heroku-postgresql:ronin", "attachment_name"=>"HEROKU_POSTGRESQL_RED"}])
          stderr, stdout = execute("addons")
          stderr.should == ""
          stdout.should == <<-STDOUT
heroku-postgresql:ronin => HEROKU_POSTGRESQL_RED
STDOUT
        end
      end
    end

    describe "list" do
      before do
        stub_core.addons.returns([
          { "name" => "cloudcounter:basic", "state" => "alpha" },
          { "name" => "cloudcounter:pro", "state" => "public" },
          { "name" => "cloudcounter:gold", "state" => "public" },
          { "name" => "cloudcounter:old", "state" => "disabled" },
          { "name" => "cloudcounter:platinum", "state" => "beta" }
        ])
      end

      it "lists available addons" do
        stderr, stdout = execute("addons:list")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== alpha
cloudcounter:basic

=== available
cloudcounter:gold, pro

=== beta
cloudcounter:platinum

=== disabled
cloudcounter:old

STDOUT
      end
    end

    describe 'v1-style command line params' do
      it "understands foo=baz" do
        @addons.stub!(:args).and_return(%w(my_addon foo=baz))
        @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "gives a deprecation notice with an example" do
        stub_request(:post, %r{apps/myapp/addons/my_addon$}).
          with(:body => {:config => {:foo => 'bar', :extra => "XXX"}})
        stderr, stdout = execute("addons:add my_addon --foo=bar extra=XXX")
        stderr.should == ""
        stdout.should include("Warning: non-unix style params have been deprecated, use --extra=XXX instead")
      end

      it "includes a complete example" do
        stub_request(:post, %r{apps/myapp/addons/my_addon$}).
          with(:body => {:config => {:foo => 'bar', :extra => "XXX"}})
        stderr, stdout = execute("addons:add my_addon foo=bar extra=XXX")
        stderr.should == ""
        stdout.should include("Warning: non-unix style params have been deprecated, use --foo=bar --extra=XXX instead")
      end
    end

    describe 'unix-style command line params' do
      it "understands --foo=baz" do
        @addons.stub!(:args).and_return(%w(my_addon --foo=baz))
        @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "understands --foo baz" do
        @addons.stub!(:args).and_return(%w(my_addon --foo baz))
        @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "treats lone switches as true" do
        @addons.stub!(:args).and_return(%w(my_addon --foo))
        @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => true })
        @addons.add
      end

      it "converts 'true' to boolean" do
        @addons.stub!(:args).and_return(%w(my_addon --foo=true))
        @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => true })
        @addons.add
      end

      it "works with many config vars" do
        @addons.stub!(:args).and_return(%w(my_addon --foo  baz --bar  yes --baz=foo --bab --bob=true))
        @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => 'baz', 'bar' => 'yes', 'baz' => 'foo', 'bab' => true, 'bob' => true })
        @addons.add
      end

      it "sends the variables to the server" do
        stub_request(:post, %r{apps/myapp/addons/my_addon$}).
          with(:body => {:config => { 'foo' => 'baz', 'bar' => 'yes', 'baz' => 'foo', 'bab' => 'true', 'bob' => 'true' }})
        stderr, stdout = execute("addons:add my_addon --foo  baz --bar  yes --baz=foo --bab --bob=true")
        stderr.should == ""
      end

      it "raises an error for spurious arguments" do
        @addons.stub!(:args).and_return(%w(my_addon spurious))
        lambda { @addons.add }.should raise_error(CommandFailed)
      end
    end

    describe "mixed options" do
      it "understands foo=bar and --baz=bar on the same line" do
        @addons.stub!(:args).and_return(%w(my_addon foo=baz --baz=bar bob=true --bar))
        @addons.heroku.should_receive(:install_addon).with('myapp', 'my_addon', { 'foo' => 'baz', 'baz' => 'bar', 'bar' => true, 'bob' => true })
        @addons.add
      end

      it "sends the variables to the server" do
        stub_request(:post, %r{apps/myapp/addons/my_addon$}).
          with(:body => {:config => { 'foo' => 'baz', 'baz' => 'bar', 'bar' => 'true', 'bob' => 'true' }})
        stderr, stdout = execute("addons:add my_addon foo=baz --baz=bar bob=true --bar")
        stderr.should == ""
        stdout.should include("Warning: non-unix style params have been deprecated, use --foo=baz --bob=true instead")
      end
    end

    describe "fork and follow switches" do
      it "should only resolve for heroku-postgresql addon" do
        %w{fork follow}.each do |switch|
          @addons.stub!(:args).and_return("addon --#{switch} HEROKU_POSTGRESQL_RED".split)
          @addons.heroku.should_receive(:install_addon).
            with('myapp', 'addon', {switch => 'HEROKU_POSTGRESQL_RED'})
          @addons.add
        end
      end

      it "should translate --fork and --follow" do
        %w{fork follow}.each do |switch|
          @addons.heroku.stub!(:config_vars => { 'HEROKU_POSTGRESQL_RED_URL' => 'foo'})
          @addons.stub!(:args).and_return("heroku-postgresql --#{switch} HEROKU_POSTGRESQL_RED".split)
          @addons.heroku.should_receive(:install_addon).with('myapp', 'heroku-postgresql', {switch => 'foo'})
          @addons.add
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

      it "adds an addon with a price" do
        stub_core.install_addon("myapp", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:add my_addon")
        stderr.should == ""
        stdout.should =~ /\(free\)/
      end

      it "adds an addon with a price and message" do
        stub_core.install_addon("myapp", "my_addon", {}).returns({ "price" => "free", "message" => "foo" })
        stderr, stdout = execute("addons:add my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
----> Adding my_addon to myapp... done, v99 (free)
      foo
OUTPUT
      end

      it "adds an addon with a price and multiline message" do
        stub_core.install_addon("myapp", "my_addon", {}).returns({ "price" => "$200/mo", "message" => "foo\nbar" })
        stderr, stdout = execute("addons:add my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
----> Adding my_addon to myapp... done, v99 ($200/mo)
      foo
      bar
OUTPUT
      end

      it "displays an error with unexpected options" do
        Heroku::Command.should_receive(:error).with("Unexpected arguments: bar")
        run("addons:add redistogo -a foo bar")
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
        @addons.stub!(:args).and_return(%w(my_addon --foo=baz))
        @addons.heroku.should_receive(:upgrade_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
        @addons.upgrade
      end

      it "adds an addon with a price" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:upgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
----> Upgrading my_addon to myapp... done, v99 (free)
OUTPUT
      end

      it "adds an addon with a price and message" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:upgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
----> Upgrading my_addon to myapp... done, v99 (free)
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
        @addons.stub!(:args).and_return(%w(my_addon --foo=baz))
        @addons.heroku.should_receive(:upgrade_addon).with('myapp', 'my_addon', { 'foo' => 'baz' })
        @addons.downgrade
      end

      it "downgrades an addon with a price" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:downgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
----> Downgrading my_addon to myapp... done, v99 (free)
OUTPUT
      end

      it "downgrades an addon with a price and message" do
        stub_core.upgrade_addon("myapp", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:downgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
----> Downgrading my_addon to myapp... done, v99 (free)
      Don't Panic
OUTPUT
      end
    end

    it "asks the user to confirm billing when API responds with 402" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      e = RestClient::RequestFailed.new
      e.stub!(:http_code).and_return(402)
      e.stub!(:http_body).and_return('{"error":"test"}')
      @addons.heroku.should_receive(:install_addon).and_raise(e)
      @addons.should_receive(:confirm_billing).and_return(false)
      STDERR.should_receive(:puts).with(" !    test")
      lambda { @addons.add }.should raise_error(SystemExit)
    end

    it "does not remove addons with no confirm" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      @addons.should_receive(:confirm_command).once.and_return(false)
      @addons.heroku.should_not_receive(:uninstall_addon)
      @addons.remove
    end

    it "removes addons after prompting for confirmation" do
      @addons.stub!(:args).and_return(%w( addon1 ))
      @addons.should_receive(:confirm_command).once.and_return(true)
      @addons.heroku.should_receive(:uninstall_addon).with('myapp', 'addon1', :confirm => "myapp")
      @addons.remove
    end

    it "removes addons with confirm option" do
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

      it "complains if no such addon exists" do
        @addons.heroku.should_receive(:addons).and_return([])
        @addons.heroku.should_receive(:installed_addons).with("myapp").and_return([])
        @addons.should_receive(:error).with("Unknown addon: red")
        @addons.open
      end

      it "complains if addon is not installed" do
        @addons.heroku.should_receive(:addons).and_return([
          { 'name' => 'redistogo:basic' }
        ])
        @addons.heroku.should_receive(:installed_addons).with("myapp").and_return([])
        @addons.should_receive(:error).with("Addon not installed: red")
        @addons.open
      end
    end
  end
end
