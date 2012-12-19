require "spec_helper"
require "heroku/command/addons"

module Heroku::Command
  describe Addons do
    before do
      @addons = prepare_command(Addons)
      stub_core.release("example", "current").returns( "name" => "v99" )
    end

    describe "index" do

      before(:each) do
        stub_core
        api.post_app("name" => "example", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "should display no addons when none are configured" do
        stderr, stdout = execute("addons")
        stderr.should == ""
        stdout.should == <<-STDOUT
example has no add-ons.
STDOUT
      end

      it "should list addons and attachments" do
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/addons$}
          },
          {
            :body   => Heroku::API::OkJson.encode([
              { 'configured' => false, 'name' => 'deployhooks:email' },
              { 'attachment_name' => 'HEROKU_POSTGRESQL_RED', 'configured' => true, 'name' => 'heroku-postgresql:ronin' },
              { 'configured' => true, 'name' => 'deployhooks:http' }
            ]),
            :status => 200,
          }
        )
        stderr, stdout = execute("addons")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== example Configured Add-ons
deployhooks:http
heroku-postgresql:ronin  HEROKU_POSTGRESQL_RED

=== example Add-ons to Configure
deployhooks:email  https://api.heroku.com/apps/example/addons/deployhooks:email

STDOUT
        Excon.stubs.shift
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
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "gives a deprecation notice with an example" do
        stub_request(:post, %r{apps/example/addons/my_addon$}).
          with(:body => {:config => {:foo => 'bar', :extra => "XXX"}}).
          to_return(:body => Heroku::OkJson.encode({ 'price' => 'free' }))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => Heroku::API::OkJson.encode({ 'name' => 'v99' }),
            :status => 200,
          }
        )
        stderr, stdout = execute("addons:add my_addon --foo=bar extra=XXX")
        stderr.should == ""
        stdout.should == <<-STDOUT
Warning: non-unix style params have been deprecated, use --extra=XXX instead
Adding my_addon on example... done, v99 (free)
Use `heroku addons:docs my_addon` to view documentation.
STDOUT
        Excon.stubs.shift
      end
    end

    describe 'unix-style command line params' do
      it "understands --foo=baz" do
        @addons.stub!(:args).and_return(%w(my_addon --foo=baz))
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "understands --foo baz" do
        @addons.stub!(:args).and_return(%w(my_addon --foo baz))
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "treats lone switches as true" do
        @addons.stub!(:args).and_return(%w(my_addon --foo))
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', { 'foo' => true })
        @addons.add
      end

      it "converts 'true' to boolean" do
        @addons.stub!(:args).and_return(%w(my_addon --foo=true))
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', { 'foo' => true })
        @addons.add
      end

      it "works with many config vars" do
        @addons.stub!(:args).and_return(%w(my_addon --foo  baz --bar  yes --baz=foo --bab --bob=true))
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz', 'bar' => 'yes', 'baz' => 'foo', 'bab' => true, 'bob' => true })
        @addons.add
      end

      it "sends the variables to the server" do
        stub_request(:post, %r{apps/example/addons/my_addon$}).
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
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz', 'baz' => 'bar', 'bar' => true, 'bob' => true })
        @addons.add
      end

      it "sends the variables to the server" do
        stub_request(:post, %r{apps/example/addons/my_addon$}).
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
            with('example', 'addon', {switch => 'HEROKU_POSTGRESQL_RED'})
          @addons.add
        end
      end

      it "should translate --fork and --follow" do
        %w{fork follow}.each do |switch|
          @addons.stub!(:app_config_vars).and_return({})
          @addons.stub!(:app_attachments).and_return([Heroku::Helpers::HerokuPostgresql::Attachment.new({
              'config_var' => 'HEROKU_POSTGRESQL_RED_URL',
              'resource' => {'name'  => 'loudly-yelling-1232',
                             'value' => 'postgres://red_url',
                             'type'  => 'heroku-postgresql:ronin' }})
          ])
          @addons.stub!(:args).and_return("heroku-postgresql --#{switch} HEROKU_POSTGRESQL_RED".split)
          @addons.heroku.should_receive(:install_addon).with('example', 'heroku-postgresql', {switch => 'postgres://red_url'})
          @addons.add
        end
      end

      it "should NOT translate --fork and --follow if passed in a full postgres url even if there are no databases" do
        %w{fork follow}.each do |switch|
          @addons.stub!(:app_config_vars).and_return({})
          @addons.stub!(:app_attachments).and_return([])
          @addons.stub!(:args).and_return("heroku-postgresql --#{switch} postgres://foo:yeah@awesome.com:234/bestdb".split)
          @addons.heroku.should_receive(:install_addon).with('example', 'heroku-postgresql', {switch => 'postgres://foo:yeah@awesome.com:234/bestdb'})
          @addons.add
        end
      end
    end

    describe 'adding' do
      before do
        @addons.stub!(:args).and_return(%w(my_addon))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => Heroku::API::OkJson.encode({ 'name' => 'v99' }),
            :status => 200,
          }
        )
      end
      after do
        Excon.stubs.shift
      end


      it "requires an addon name" do
        @addons.stub!(:args).and_return([])
        lambda { @addons.add }.should raise_error(CommandFailed)
      end

      it "adds an addon" do
        @addons.stub!(:args).and_return(%w(my_addon))
        @addons.heroku.should_receive(:install_addon).with('example', 'my_addon', {})
        @addons.add
      end

      it "adds an addon with a price" do
        stub_core.install_addon("example", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:add my_addon")
        stderr.should == ""
        stdout.should =~ /\(free\)/
      end

      it "adds an addon with a price and message" do
        stub_core.install_addon("example", "my_addon", {}).returns({ "price" => "free", "message" => "foo" })
        stderr, stdout = execute("addons:add my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Adding my_addon on example... done, v99 (free)
foo
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "adds an addon with a price and multiline message" do
        stub_core.install_addon("example", "my_addon", {}).returns({ "price" => "$200/mo", "message" => "foo\nbar" })
        stderr, stdout = execute("addons:add my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Adding my_addon on example... done, v99 ($200/mo)
foo
bar
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "displays an error with unexpected options" do
        Heroku::Command.should_receive(:error).with("Unexpected arguments: bar")
        run("addons:add redistogo -a foo bar")
      end
    end

    describe 'upgrading' do
      before do
        @addons.stub!(:args).and_return(%w(my_addon))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => Heroku::API::OkJson.encode({ 'name' => 'v99' }),
            :status => 200,
          }
        )
      end
      after do
        Excon.stubs.shift
      end

      it "requires an addon name" do
        @addons.stub!(:args).and_return([])
        lambda { @addons.upgrade }.should raise_error(CommandFailed)
      end

      it "upgrades an addon" do
        @addons.stub!(:args).and_return(%w(my_addon))
        @addons.heroku.should_receive(:upgrade_addon).with('example', 'my_addon', {})
        @addons.upgrade
      end

      it "upgrade an addon with config vars" do
        @addons.stub!(:args).and_return(%w(my_addon --foo=baz))
        @addons.heroku.should_receive(:upgrade_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.upgrade
      end

      it "adds an addon with a price" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:upgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Upgrading to my_addon on example... done, v99 (free)
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "adds an addon with a price and message" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:upgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Upgrading to my_addon on example... done, v99 (free)
Don't Panic
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end
    end

    describe 'downgrading' do
      before do
        @addons.stub!(:args).and_return(%w(my_addon))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => Heroku::API::OkJson.encode({ 'name' => 'v99' }),
            :status => 200,
          }
        )
      end
      after do
        Excon.stubs.shift
      end

      it "requires an addon name" do
        @addons.stub!(:args).and_return([])
        lambda { @addons.downgrade }.should raise_error(CommandFailed)
      end

      it "downgrades an addon" do
        @addons.stub!(:args).and_return(%w(my_addon))
        @addons.heroku.should_receive(:upgrade_addon).with('example', 'my_addon', {})
        @addons.downgrade
      end

      it "downgrade an addon with config vars" do
        @addons.stub!(:args).and_return(%w(my_addon --foo=baz))
        @addons.heroku.should_receive(:upgrade_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.downgrade
      end

      it "downgrades an addon with a price" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:downgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Downgrading to my_addon on example... done, v99 (free)
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "downgrades an addon with a price and message" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:downgrade my_addon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Downgrading to my_addon on example... done, v99 (free)
Don't Panic
Use `heroku addons:docs my_addon` to view documentation.
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
      @addons.heroku.should_receive(:uninstall_addon).with('example', 'addon1', :confirm => "example")
      @addons.remove
    end

    it "removes addons with confirm option" do
      Heroku::Command.stub!(:current_options).and_return(:confirm => "example")
      @addons.stub!(:args).and_return(%w( addon1 ))
      @addons.heroku.should_receive(:uninstall_addon).with('example', 'addon1', :confirm => "example")
      @addons.remove
    end

    describe "opening add-on docs" do

      before(:each) do
        stub_core
        api.post_app("name" => "example", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "displays usage when no argument is specified" do
        stderr, stdout = execute('addons:docs')
        stderr.should == <<-STDERR
 !    Usage: heroku addons:docs ADDON
 !    Must specify ADDON to open docs for.
STDERR
        stdout.should == ''
      end

      it "opens the addon if only one matches" do
        require("launchy")
        Launchy.should_receive(:open).with("https://devcenter.heroku.com/articles/redistogo").and_return(Thread.new {})
        stderr, stdout = execute('addons:docs redistogo:nano')
        stderr.should == ''
        stdout.should == <<-STDOUT
Opening redistogo:nano docs... done
STDOUT
      end

      it "complains about ambiguity" do
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/addons$}
          },
          {
            :body   => Heroku::API::OkJson.encode([
              { 'name' => 'qux:foo' },
              { 'name' => 'quux:bar' }
            ]),
            :status => 200,
          }
        )
        stderr, stdout = execute('addons:docs qu')
        stderr.should == <<-STDERR
 !    Ambiguous addon name: qu
 !    Perhaps you meant `qux:foo` or `quux:bar`.
STDERR
        stdout.should == ''
        Excon.stubs.shift
      end

      it "complains if no such addon exists" do
        stderr, stdout = execute('addons:docs unknown')
        stderr.should == <<-STDERR
 !    `unknown` is not a heroku add-on.
 !    See `heroku addons:list` for all available addons.
STDERR
        stdout.should == ''
      end

      it "suggests alternatives if addon has typo" do
        stderr, stdout = execute('addons:docs redisgoto')
        stderr.should == <<-STDERR
 !    `redisgoto` is not a heroku add-on.
 !    Perhaps you meant `redistogo`.
 !    See `heroku addons:list` for all available addons.
STDERR
        stdout.should == ''
      end

      it "complains if addon is not installed" do
        stderr, stdout = execute('addons:open deployhooks:http')
        stderr.should == <<-STDOUT
 !    Addon not installed: deployhooks:http
STDOUT
        stdout.should == ''
      end
    end
    describe "opening an addon" do

      before(:each) do
        stub_core
        api.post_app("name" => "example", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "displays usage when no argument is specified" do
        stderr, stdout = execute('addons:open')
        stderr.should == <<-STDERR
 !    Usage: heroku addons:open ADDON
 !    Must specify ADDON to open.
STDERR
        stdout.should == ''
      end

      it "opens the addon if only one matches" do
        api.post_addon('example', 'redistogo:nano')
        require("launchy")
        Launchy.should_receive(:open).with("https://api.#{@addons.heroku.host}/apps/example/addons/redistogo:nano").and_return(Thread.new {})
        stderr, stdout = execute('addons:open redistogo:nano')
        stderr.should == ''
        stdout.should == <<-STDOUT
Opening redistogo:nano for example... done
STDOUT
      end

      it "complains about ambiguity" do
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/addons$}
          },
          {
            :body   => Heroku::API::OkJson.encode([
              { 'name' => 'deployhooks:email' },
              { 'name' => 'deployhooks:http' }
            ]),
            :status => 200,
          }
        )
        stderr, stdout = execute('addons:open deployhooks')
        stderr.should == <<-STDERR
 !    Ambiguous addon name: deployhooks
 !    Perhaps you meant `deployhooks:email` or `deployhooks:http`.
STDERR
        stdout.should == ''
        Excon.stubs.shift
      end

      it "complains if no such addon exists" do
        stderr, stdout = execute('addons:open unknown')
        stderr.should == <<-STDERR
 !    `unknown` is not a heroku add-on.
 !    See `heroku addons:list` for all available addons.
STDERR
        stdout.should == ''
      end

      it "suggests alternatives if addon has typo" do
        stderr, stdout = execute('addons:open redisgoto')
        stderr.should == <<-STDERR
 !    `redisgoto` is not a heroku add-on.
 !    Perhaps you meant `redistogo`.
 !    See `heroku addons:list` for all available addons.
STDERR
        stdout.should == ''
      end

      it "complains if addon is not installed" do
        stderr, stdout = execute('addons:open deployhooks:http')
        stderr.should == <<-STDOUT
 !    Addon not installed: deployhooks:http
STDOUT
        stdout.should == ''
      end
    end
  end
end
