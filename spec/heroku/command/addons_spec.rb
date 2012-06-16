require "spec_helper"
require "heroku/command/addons"

module Heroku::Command
  describe Addons do
    before do
      stub_core.release("myapp", "current").returns( "name" => "v99" )
    end

    describe "index" do

      before(:each) do
        api.post_app("name" => "myapp", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("myapp")
      end

      it "should display no addons when none are configured" do
        stderr, stdout = execute("addons")
        stderr.should == ""
        stdout.should == <<-STDOUT
No addons for myapp
STDOUT
      end

      it "should list addons and attachments" do
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/myapp/addons$}
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
=== myapp Configured Add-ons
deployhooks:http
heroku-postgresql:ronin   HEROKU_POSTGRESQL_RED

=== myapp Add-ons to Configure
deployhooks:email   https://api.heroku.com/myapps/myapp/addons/deployhooks:email

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
      it "gives a deprecation notice with an example" do
        Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'myaddon', { 'foo' => 'bar', 'extra' => 'XXX' }).and_return('price' => 'free')
        stderr, stdout = execute("addons:add myaddon --foo=bar extra=XXX")
        stderr.should == ""
        stdout.should == <<-STDOUT
Warning: non-unix style params have been deprecated, use --extra=XXX instead
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end
    end

    describe 'unix-style command line params' do
      it "understands --foo=baz" do
        Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'myaddon', { 'foo' => 'baz' }).and_return({'price' => 'free'})
        stderr, stdout = execute('addons:add myaddon --foo=baz')
        stderr.should == ''
        stdout.should == <<-STDOUT
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end

      it "understands --foo baz" do
        Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'myaddon', { 'foo' => 'baz' }).and_return({'price' => 'free'})
        stderr, stdout = execute('addons:add myaddon --foo baz')
        stderr.should == ''
        stdout.should == <<-STDOUT
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end

      it "treats lone switches as true" do
        Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'myaddon', { 'foo' => true }).and_return({'price' => 'free'})
        stderr, stdout = execute('addons:add myaddon --foo')
        stderr.should == ''
        stdout.should == <<-STDOUT
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end

      it "converts 'true' to boolean" do
        Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'myaddon', { 'foo' => true }).and_return({'price' => 'free'})
        stderr, stdout = execute('addons:add myaddon --foo=true')
        stderr.should == ''
        stdout.should == <<-STDOUT
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end

      it "works with many mixed config vars" do
        Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'myaddon', { 'foo' => 'baz', 'bar' => 'yes', 'baz' => 'foo', 'bab' => true, 'bob' => true, 'qux' => 'quux' }).and_return({'price' => 'free'})
        stderr, stdout = execute('addons:add myaddon --foo  baz --bar yes --baz=foo --bab --bob=true qux=quux')
        stderr.should == ''
        stdout.should == <<-STDOUT
Warning: non-unix style params have been deprecated, use --qux=quux instead
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end

      it "raises an error for spurious arguments" do
        lambda { execute('addons:add myaddon spurious') }.should raise_error(CommandFailed, 'Unexpected arguments: spurious')
      end
    end

    describe "fork and follow switches" do
      %w{fork follow}.each do |switch|
        it "#{switch} should only resolve for heroku-postgresql addon" do
          Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'myaddon', {switch => 'HEROKU_POSTGRESQL_RED'}).and_return({'price' => 'free'})
          stderr, stdout = execute("addons:add myaddon --#{switch} HEROKU_POSTGRESQL_RED")
          stderr.should == ''
          stdout.should == <<-STDOUT
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
        end
      end

      %w{fork follow}.each do |switch|
        it "#{switch} should translate --fork and --follow" do
          Heroku::Command::Addons.any_instance.should_receive(:app_config_vars).twice.and_return({ 'HEROKU_POSTGRESQL_RED_URL' => 'foo'})
          Heroku::Client.any_instance.should_receive(:install_addon).with('myapp', 'heroku-postgresql:ronin', {switch => 'foo'}).and_return({'price' => 'free'})
          stderr, stdout = execute("addons:add heroku-postgresql:ronin --#{switch} HEROKU_POSTGRESQL_RED")
          stderr.should == ''
          stdout.should == <<-STDOUT
Adding heroku-postgresql:ronin to myapp... done, v99 (free)
heroku-postgresql:ronin documentation available at: https://devcenter.heroku.com/articles/heroku-postgresql
STDOUT
        end
      end
    end

    describe 'adding' do
      it "requires an addon name" do
        lambda { execute('addons:add') }.should raise_error(CommandFailed, 'Missing add-on name')
      end

      it "adds an addon" do
        Heroku::Client.any_instance.should_receive(:install_addon).with("myapp", "myaddon", {}).and_return({ "price" => "free" })
        stderr, stdout = execute("addons:add myaddon")
        stdout.should == <<-OUTPUT
Adding myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
OUTPUT
      end

      it "adds an addon with a price and message" do
        Heroku::Client.any_instance.should_receive(:install_addon).with("myapp", "myaddon", {}).and_return({ "price" => "free", "message" => "foo" })
        stderr, stdout = execute("addons:add myaddon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Adding myaddon to myapp... done, v99 (free)
foo
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
OUTPUT
      end

      it "adds an addon with a price and multiline message" do
        Heroku::Client.any_instance.should_receive(:install_addon).with("myapp", "myaddon", {}).and_return({ "price" => "$200/mo", "message" => "foo\nbar" })
        stderr, stdout = execute("addons:add myaddon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Adding myaddon to myapp... done, v99 ($200/mo)
foo
bar
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
OUTPUT
      end

      it "displays an error with unexpected options" do
        Heroku::Command.should_receive(:error).with("Unexpected arguments: bar")
        run("addons:add redistogo -a foo bar")
      end

      it "asks the user to confirm billing when API responds with 402" do
        e = RestClient::RequestFailed.new
        e.stub!(:http_code).and_return(402)
        e.stub!(:http_body).and_return('{"error":"test"}')
        Heroku::Client.any_instance.should_receive(:install_addon).and_raise(e)
        Heroku::Command::Addons.any_instance.should_receive(:confirm_billing).and_return(false)
        stderr, stdout = execute('addons:add myaddon')
        stderr.should == <<-STDERR
 !    test
STDERR
        stdout.should == <<-STDOUT
Adding myaddon to myapp... failed
STDOUT
      end

    end

    describe 'upgrading' do
      it "requires an addon name" do
        lambda { execute('addons:upgrade') }.should raise_error(CommandFailed, 'Missing add-on name')
      end

      it "upgrades an addon" do
        Heroku::Client.any_instance.should_receive(:upgrade_addon).with("myapp", "myaddon", {}).and_return({ "price" => "free" })
        stderr, stdout = execute("addons:upgrade myaddon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Upgrading myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
OUTPUT
      end

      it "upgrade an addon with config vars" do
        Heroku::Client.any_instance.should_receive(:upgrade_addon).with('myapp', 'myaddon', { 'foo' => 'baz' }).and_return({ 'price' => 'free' })
        stderr, stdout = execute('addons:upgrade myaddon --foo=baz')
        stderr.should == ''
        stdout.should == <<-OUTPUT
Upgrading myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
OUTPUT

      end

      it "upgrades an addon with a price and message" do
        Heroku::Client.any_instance.should_receive(:upgrade_addon).with("myapp", "myaddon", {}).and_return({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:upgrade myaddon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Upgrading myaddon to myapp... done, v99 (free)
Don't Panic
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
OUTPUT
      end
    end

    describe 'downgrading' do
      it "requires an addon name" do
        lambda { execute('addons:downgrade') }.should raise_error(CommandFailed, 'Missing add-on name')
      end

      it "downgrades an addon" do
        Heroku::Client.any_instance.should_receive(:upgrade_addon).with('myapp', 'myaddon', {}).and_return({'price' => 'free'})
        stderr, stdout = execute('addons:downgrade myaddon')
        stderr.should == ''
        stdout.should == <<-STDOUT
Downgrading myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end

      it "downgrade an addon with config vars" do
        Heroku::Client.any_instance.should_receive(:upgrade_addon).with('myapp', 'myaddon', { 'foo' => 'baz' }).and_return({'price' => 'free'})
        stderr, stdout = execute('addons:downgrade myaddon --foo=baz')
        stderr.should == ''
        stdout.should == <<-STDOUT
Downgrading myaddon to myapp... done, v99 (free)
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
STDOUT
      end

      it "downgrades an addon with a price and message" do
        Heroku::Client.any_instance.should_receive(:upgrade_addon).with("myapp", "myaddon", {}).and_return({ "price" => "free", "message" => "Don't Panic" })
        stderr, stdout = execute("addons:downgrade myaddon")
        stderr.should == ""
        stdout.should == <<-OUTPUT
Downgrading myaddon to myapp... done, v99 (free)
Don't Panic
myaddon documentation available at: https://devcenter.heroku.com/articles/myaddon
OUTPUT
      end
    end

    context "remove" do
      it "does not remove addons with no confirm" do
        stderr, stdout = execute('addons:remove myaddon')
        stderr.should == <<-STDERR
 !    Confirmation did not match myapp. Aborted.
STDERR
        stdout.should == <<-STDOUT + '> '

 !    WARNING: Destructive Action
 !    This command will affect the app: myapp
 !    To proceed, type \"myapp\" or re-run this command with --confirm myapp

STDOUT
      end

      it "removes addons after prompting for confirmation" do
        Heroku::Command::Addons.any_instance.should_receive(:confirm_command).and_return(true)
        Heroku::Client.any_instance.should_receive(:uninstall_addon).with('myapp', 'myaddon', :confirm => "myapp").and_return({'price' => 'free'})
        stderr, stdout = execute('addons:remove myaddon')
        stderr.should == ''
        stdout.should == <<-STDOUT
Removing myaddon from myapp... done, v99 (free)

STDOUT
      end

      it "removes addons with confirm option" do
        Heroku::Client.any_instance.should_receive(:uninstall_addon).with('myapp', 'myaddon', :confirm => "myapp").and_return({'price' => 'free'})
        stderr, stdout = execute('addons:remove myaddon --confirm myapp')
        stderr.should == ''
        stdout.should == <<-STDOUT
Removing myaddon from myapp... done, v99 (free)

STDOUT
      end
    end

    describe "opening add-on docs" do

      before(:each) do
        stub_core
        api.post_app("name" => "myapp", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("myapp")
      end

      it "displays usage when no argument is specified" do
        stderr, stdout = execute('addons:docs')
        stderr.should == <<-STDERR
 !    Usage: heroku addons:docs ADDON
 !    Must specify addon.
STDERR
        stdout.should == ''
      end

      it "opens the addon if only one matches" do
        require("launchy")
        Launchy.should_receive(:open).with("https://devcenter.heroku.com/articles/redistogo")
        stderr, stdout = execute('addons:docs redistogo:nano')
        stderr.should == ''
        stdout.should == <<-STDOUT
Opening redistogo docs... done
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
        api.post_app("name" => "myapp", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("myapp")
      end

      it "displays usage when no argument is specified" do
        stderr, stdout = execute('addons:open')
        stderr.should == <<-STDERR
 !    Usage: heroku addons:open ADDON
 !    Must specify addon.
STDERR
        stdout.should == ''
      end

      it "opens the addon if only one matches" do
        api.post_addon('myapp', 'redistogo:nano')
        require("launchy")
        Launchy.should_receive(:open).with("https://api.heroku.com/myapps/myapp/addons/redistogo:nano")
        stderr, stdout = execute('addons:open redistogo:nano')
        stderr.should == ''
        stdout.should == <<-STDOUT
Opening redistogo:nano for myapp... done
STDOUT
      end

      it "complains about ambiguity" do
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => %r{^/apps/myapp/addons$}
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
