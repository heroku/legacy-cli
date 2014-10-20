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
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
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
            :body   => MultiJson.dump([
              { 'configured' => false, 'name' => 'deployhooks:email' },
              { 'attachment_name' => 'HEROKU_POSTGRESQL_RED', 'configured' => true, 'name' => 'heroku-postgresql:ronin' },
              { 'configured' => true, 'name' => 'deployhooks:http' }
            ]),
            :status => 200,
          }
        )
        stderr, stdout = execute("addons")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== example Configured Add-ons
deployhooks:http
heroku-postgresql:ronin  HEROKU_POSTGRESQL_RED

=== example Add-ons to Configure
deployhooks:email  https://addons-sso.heroku.com/apps/example/addons/deployhooks:email

STDOUT
        Excon.stubs.shift
      end

    end

    describe "list" do

      it "sends region option to the server" do
        stub_request(:get, %r{/addons\?region=eu$}).
          to_return(:body => MultiJson.dump([]))
        execute("addons:list --region=eu")
      end

      it "lists available addons" do
        stub_core.addons.returns([
          { "name" => "cloudcounter:basic", "state" => "alpha" },
          { "name" => "cloudcounter:pro", "state" => "public" },
          { "name" => "cloudcounter:gold", "state" => "public" },
          { "name" => "cloudcounter:old", "state" => "disabled" },
          { "name" => "cloudcounter:platinum", "state" => "beta" }
        ])
        stderr, stdout = execute("addons:list")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
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
        allow(@addons).to receive(:args).and_return(%w(my_addon foo=baz))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "gives a deprecation notice with an example" do
        stub_request(:post, %r{apps/example/addons/my_addon$}).
          with(:body => {:config => {:foo => 'bar', :extra => "XXX"}}).
          to_return(:body => MultiJson.dump({ 'price' => 'free' }))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => MultiJson.dump({ 'name' => 'v99' }),
            :status => 200,
          }
        )
        stderr, stdout = execute("addons:add my_addon --foo=bar extra=XXX")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Warning: non-unix style params have been deprecated, use --extra=XXX instead
Adding my_addon on example... done, v99 (free)
Use `heroku addons:docs my_addon` to view documentation.
STDOUT
        Excon.stubs.shift
      end
    end

    describe 'unix-style command line params' do
      it "understands --foo=baz" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo=baz))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "understands --foo baz" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo baz))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.add
      end

      it "treats lone switches as true" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', { 'foo' => true })
        @addons.add
      end

      it "converts 'true' to boolean" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo=true))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', { 'foo' => true })
        @addons.add
      end

      it "works with many config vars" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo  baz --bar  yes --baz=foo --bab --bob=true))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz', 'bar' => 'yes', 'baz' => 'foo', 'bab' => true, 'bob' => true })
        @addons.add
      end

      it "sends the variables to the server" do
        stub_request(:post, %r{apps/example/addons/my_addon$}).
          with(:body => {:config => { 'foo' => 'baz', 'bar' => 'yes', 'baz' => 'foo', 'bab' => 'true', 'bob' => 'true' }})
        stderr, stdout = execute("addons:add my_addon --foo  baz --bar  yes --baz=foo --bab --bob=true")
        expect(stderr).to eq("")
      end

      it "raises an error for spurious arguments" do
        allow(@addons).to receive(:args).and_return(%w(my_addon spurious))
        expect { @addons.add }.to raise_error(CommandFailed)
      end
    end

    describe "mixed options" do
      it "understands foo=bar and --baz=bar on the same line" do
        allow(@addons).to receive(:args).and_return(%w(my_addon foo=baz --baz=bar bob=true --bar))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', { 'foo' => 'baz', 'baz' => 'bar', 'bar' => true, 'bob' => true })
        @addons.add
      end

      it "sends the variables to the server" do
        stub_request(:post, %r{apps/example/addons/my_addon$}).
          with(:body => {:config => { 'foo' => 'baz', 'baz' => 'bar', 'bar' => 'true', 'bob' => 'true' }})
        stderr, stdout = execute("addons:add my_addon foo=baz --baz=bar bob=true --bar")
        expect(stderr).to eq("")
        expect(stdout).to include("Warning: non-unix style params have been deprecated, use --foo=baz --bob=true instead")
      end
    end

    describe "fork, follow, and rollback switches" do
      it "should only resolve for heroku-postgresql addon" do
        %w{fork follow rollback}.each do |switch|
          allow(@addons).to receive(:args).and_return("addon --#{switch} HEROKU_POSTGRESQL_RED".split)
          expect(@addons.heroku).to receive(:install_addon).
            with('example', 'addon', {switch => 'HEROKU_POSTGRESQL_RED'})
          @addons.add
        end
      end

      it "should translate --fork, --follow, and --rollback" do
        %w{fork follow rollback}.each do |switch|
          allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver).to receive(:app_config_vars).and_return({})
          allow_any_instance_of(Heroku::Helpers::HerokuPostgresql::Resolver).to receive(:app_attachments).and_return([Heroku::Helpers::HerokuPostgresql::Attachment.new({
              'app' => {'name' => 'sushi'},
              'name' => 'HEROKU_POSTGRESQL_RED',
              'config_var' => 'HEROKU_POSTGRESQL_RED_URL',
              'resource' => {'name'  => 'loudly-yelling-1232',
                             'value' => 'postgres://red_url',
                             'type'  => 'heroku-postgresql:ronin' }})
          ])
          allow(@addons).to receive(:args).and_return("heroku-postgresql --#{switch} HEROKU_POSTGRESQL_RED".split)
          expect(@addons.heroku).to receive(:install_addon).with('example', 'heroku-postgresql:ronin', {switch => 'postgres://red_url'})
          @addons.add
        end
      end

      it "should NOT translate --fork and --follow if passed in a full postgres url even if there are no databases" do
        %w{fork follow}.each do |switch|
          allow(@addons).to receive(:app_config_vars).and_return({})
          allow(@addons).to receive(:app_attachments).and_return([])
          allow(@addons).to receive(:args).and_return("heroku-postgresql:ronin --#{switch} postgres://foo:yeah@awesome.com:234/bestdb".split)
          expect(@addons.heroku).to receive(:install_addon).with('example', 'heroku-postgresql:ronin', {switch => 'postgres://foo:yeah@awesome.com:234/bestdb'})
          @addons.add
        end
      end

      it "should fail if fork / follow across applications and no plan is specified" do
        %w{fork follow}.each do |switch|
          allow(@addons).to receive(:app_config_vars).and_return({})
          allow(@addons).to receive(:app_attachments).and_return([])
          allow(@addons).to receive(:args).and_return("heroku-postgresql --#{switch} postgres://foo:yeah@awesome.com:234/bestdb".split)
          expect { @addons.add }.to raise_error(CommandFailed)
        end
      end
    end

    describe 'adding' do
      before do
        allow(@addons).to receive(:args).and_return(%w(my_addon))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => MultiJson.dump({ 'name' => 'v99' }),
            :status => 200,
          }
        )
      end
      after do
        Excon.stubs.shift
      end


      it "requires an addon name" do
        allow(@addons).to receive(:args).and_return([])
        expect { @addons.add }.to raise_error(CommandFailed)
      end

      it "adds an addon" do
        allow(@addons).to receive(:args).and_return(%w(my_addon))
        expect(@addons.heroku).to receive(:install_addon).with('example', 'my_addon', {})
        @addons.add
      end

      it "adds an addon with a price" do
        stub_core.install_addon("example", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:add my_addon")
        expect(stderr).to eq("")
        expect(stdout).to match(/\(free\)/)
      end

      it "adds an addon with a price and message" do
        stub_core.install_addon("example", "my_addon", {}).returns({ "price" => "free", "message" => "foo" })
        stderr, stdout = execute("addons:add my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Adding my_addon on example... done, v99 (free)
foo
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "excludes addon plan from docs message" do
        stub_core.install_addon("example", "my_addon:test", {}).returns({ "price" => "free", "message" => "foo" })
        stderr, stdout = execute("addons:add my_addon:test")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Adding my_addon:test on example... done, v99 (free)
foo
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "adds an addon with a price and multiline message" do
        stub_core.install_addon("example", "my_addon", {}).returns({ "price" => "$200/mo", "message" => "foo\nbar" })
        stderr, stdout = execute("addons:add my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Adding my_addon on example... done, v99 ($200/mo)
foo
bar
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "displays an error with unexpected options" do
        expect(Heroku::Command).to receive(:error).with("Unexpected arguments: bar")
        run("addons:add redistogo -a foo bar")
      end
    end

    describe 'upgrading' do
      before do
        allow(@addons).to receive(:args).and_return(%w(my_addon))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => MultiJson.dump({ 'name' => 'v99' }),
            :status => 200,
          }
        )
      end
      after do
        Excon.stubs.shift
      end

      it "requires an addon name" do
        allow(@addons).to receive(:args).and_return([])
        expect { @addons.upgrade }.to raise_error(CommandFailed)
      end

      it "upgrades an addon" do
        allow(@addons).to receive(:args).and_return(%w(my_addon))
        expect(@addons.heroku).to receive(:upgrade_addon).with('example', 'my_addon', {})
        @addons.upgrade
      end

      it "upgrade an addon with config vars" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo=baz))
        expect(@addons.heroku).to receive(:upgrade_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.upgrade
      end

      it "adds an addon with a price" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:upgrade my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Upgrading to my_addon on example... done, v99 (free)
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "adds an addon with a price and message" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:upgrade my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Upgrading to my_addon on example... done, v99 (free)
Don't Panic
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end
    end

    describe 'downgrading' do
      before do
        allow(@addons).to receive(:args).and_return(%w(my_addon))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/example/releases/current}
          },
          {
            :body   => MultiJson.dump({ 'name' => 'v99' }),
            :status => 200,
          }
        )
      end
      after do
        Excon.stubs.shift
      end

      it "requires an addon name" do
        allow(@addons).to receive(:args).and_return([])
        expect { @addons.downgrade }.to raise_error(CommandFailed)
      end

      it "downgrades an addon" do
        allow(@addons).to receive(:args).and_return(%w(my_addon))
        expect(@addons.heroku).to receive(:upgrade_addon).with('example', 'my_addon', {})
        @addons.downgrade
      end

      it "downgrade an addon with config vars" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo=baz))
        expect(@addons.heroku).to receive(:upgrade_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.downgrade
      end

      it "downgrades an addon with a price" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free" })
        stderr, stdout = execute("addons:downgrade my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Downgrading to my_addon on example... done, v99 (free)
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end

      it "downgrades an addon with a price and message" do
        stub_core.upgrade_addon("example", "my_addon", {}).returns({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:downgrade my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Downgrading to my_addon on example... done, v99 (free)
Don't Panic
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT
      end
    end

    it "does not remove addons with no confirm" do
      allow(@addons).to receive(:args).and_return(%w( addon1 ))
      expect(@addons).to receive(:confirm_command).once.and_return(false)
      expect(@addons.heroku).not_to receive(:uninstall_addon)
      @addons.remove
    end

    it "removes addons after prompting for confirmation" do
      allow(@addons).to receive(:args).and_return(%w( addon1 ))
      expect(@addons).to receive(:confirm_command).once.and_return(true)
      expect(@addons.heroku).to receive(:uninstall_addon).with('example', 'addon1', :confirm => "example")
      @addons.remove
    end

    it "removes addons with confirm option" do
      allow(Heroku::Command).to receive(:current_options).and_return(:confirm => "example")
      allow(@addons).to receive(:args).and_return(%w( addon1 ))
      expect(@addons.heroku).to receive(:uninstall_addon).with('example', 'addon1', :confirm => "example")
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
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku addons:docs ADDON
 !    Must specify ADDON to open docs for.
STDERR
        expect(stdout).to eq('')
      end

      it "opens the addon if only one matches" do
        require("launchy")
        expect(Launchy).to receive(:open).with("https://devcenter.heroku.com/articles/redistogo").and_return(Thread.new {})
        stderr, stdout = execute('addons:docs redistogo:nano')
        expect(stderr).to eq('')
        expect(stdout).to eq <<-STDOUT
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
            :body   => MultiJson.dump([
              { 'name' => 'qux:foo' },
              { 'name' => 'quux:bar' }
            ]),
            :status => 200,
          }
        )
        stderr, stdout = execute('addons:docs qu')
        expect(stderr).to eq <<-STDERR
 !    Ambiguous addon name: qu
 !    Perhaps you meant `qux:foo` or `quux:bar`.
STDERR
        expect(stdout).to eq('')
        Excon.stubs.shift
      end

      it "complains if no such addon exists" do
        stderr, stdout = execute('addons:docs unknown')
        expect(stderr).to eq <<-STDERR
 !    `unknown` is not a heroku add-on.
 !    See `heroku addons:list` for all available addons.
STDERR
        expect(stdout).to eq('')
      end

      it "suggests alternatives if addon has typo" do
        stderr, stdout = execute('addons:docs redisgoto')
        expect(stderr).to eq <<-STDERR
 !    `redisgoto` is not a heroku add-on.
 !    Perhaps you meant `redistogo`.
 !    See `heroku addons:list` for all available addons.
STDERR
        expect(stdout).to eq('')
      end

      it "complains if addon is not installed" do
        stderr, stdout = execute('addons:open deployhooks:http')
        expect(stderr).to eq <<-STDOUT
 !    Addon not installed: deployhooks:http
STDOUT
        expect(stdout).to eq('')
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
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku addons:open ADDON
 !    Must specify ADDON to open.
STDERR
        expect(stdout).to eq('')
      end

      it "opens the addon if only one matches" do
        api.post_addon('example', 'redistogo:nano')
        require("launchy")
        expect(Launchy).to receive(:open).with("https://addons-sso.heroku.com/apps/example/addons/redistogo:nano").and_return(Thread.new {})
        stderr, stdout = execute('addons:open redistogo:nano')
        expect(stderr).to eq('')
        expect(stdout).to eq <<-STDOUT
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
            :body   => MultiJson.dump([
              { 'name' => 'deployhooks:email' },
              { 'name' => 'deployhooks:http' }
            ]),
            :status => 200,
          }
        )
        stderr, stdout = execute('addons:open deployhooks')
        expect(stderr).to eq <<-STDERR
 !    Ambiguous addon name: deployhooks
 !    Perhaps you meant `deployhooks:email` or `deployhooks:http`.
STDERR
        expect(stdout).to eq('')
        Excon.stubs.shift
      end

      it "complains if no such addon exists" do
        stderr, stdout = execute('addons:open unknown')
        expect(stderr).to eq <<-STDERR
 !    `unknown` is not a heroku add-on.
 !    See `heroku addons:list` for all available addons.
STDERR
        expect(stdout).to eq('')
      end

      it "suggests alternatives if addon has typo" do
        stderr, stdout = execute('addons:open redisgoto')
        expect(stderr).to eq <<-STDERR
 !    `redisgoto` is not a heroku add-on.
 !    Perhaps you meant `redistogo`.
 !    See `heroku addons:list` for all available addons.
STDERR
        expect(stdout).to eq('')
      end

      it "complains if addon is not installed" do
        stderr, stdout = execute('addons:open deployhooks:http')
        expect(stderr).to eq <<-STDOUT
 !    Addon not installed: deployhooks:http
STDOUT
        expect(stdout).to eq('')
      end
    end
  end
end
