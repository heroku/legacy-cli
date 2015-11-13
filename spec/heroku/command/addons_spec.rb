require "spec_helper"
require "heroku/command/addons"

module Heroku::Command
  describe Addons do
    include Support::Addons
    let(:addon) { build_addon(name: "my_addon", app: { name: "example" }) }

    before do
      @addons = prepare_command(Addons)
      stub_core.release("example", "current").returns( "name" => "v99" )
    end

    describe "#index" do
      before(:each) do
        stub_core
        api.post_app("name" => "example", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "should display no addons when none are configured" do
        Excon.stub(method: :get, path: '/apps/example/addons') do
          { body: "[]", status: 200 }
        end

        Excon.stub(method: :get, path: '/apps/example/addon-attachments') do
          { body: "[]", status: 200 }
        end

        stderr, stdout = execute("addons")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== Resources for example
There are no add-ons.

=== Attachments for example
There are no attachments.
STDOUT

        Excon.stubs.shift(2)
      end

      it "should list addons and attachments" do
        Excon.stub(method: :get, path: '/apps/example/addons') do
          hooks = build_addon(
            name: "swimming-nicely-42",
            plan: { name: "deployhooks:http", price: { cents: 0, unit: "month" }},
            app:  { name: "example" })

          hpg = build_addon(
            name: "jumping-slowly-76",
            plan: { name: "heroku-postgresql:ronin", price: { cents: 20000, unit: "month" }},
            app:  { name: "example" })

          { body: MultiJson.encode([hooks, hpg]), status: 200 }
        end

        Excon.stub(method: :get, path: '/apps/example/addon-attachments') do
          hpg = build_attachment(
            name:  "HEROKU_POSTGRESQL_CYAN",
            addon: { name: "heroku-postgresql-12345", app: { name: "example" }},
            app:   { name: "example" })

          { body: MultiJson.encode([hpg]), status: 200 }
        end

        stderr, stdout = execute("addons")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== Resources for example
Plan                     Name                Price
-----------------------  ------------------  -------------
deployhooks:http         swimming-nicely-42  free
heroku-postgresql:ronin  jumping-slowly-76   $200.00/month

=== Attachments for example
Name                    Add-on                   Billing App
----------------------  -----------------------  -----------
HEROKU_POSTGRESQL_CYAN  heroku-postgresql-12345  example
STDOUT
        Excon.stubs.shift(2)
      end

    end

    describe "list" do
      before do
        Excon.stub(method: :get, path: '/addon-services') do
          services = [
            { "name" => "cloudcounter:basic", "state" => "alpha" },
            { "name" => "cloudcounter:pro", "state" => "public" },
            { "name" => "cloudcounter:gold", "state" => "public" },
            { "name" => "cloudcounter:old", "state" => "disabled" },
            { "name" => "cloudcounter:platinum", "state" => "beta" }
          ]

          { body: MultiJson.encode(services), status: 200 }
        end
      end

      after do
        Excon.stubs.shift
      end

      # TODO: plugin code doesn't support this. Do we need it?
      xit "sends region option to the server" do
        stub_request(:get, '/addon-services?region=eu').
          to_return(:body => MultiJson.dump([]))
        execute("addons:list --region=eu")
      end

      describe "when using the deprecated `addons:list` command" do
        it "displays a deprecation warning" do
          stderr, stdout = execute("addons:list")
          expect(stderr).to eq("")
          expect(stdout).to include "WARNING: `heroku addons:list` has been deprecated. Please use `heroku addons:services` instead."
        end
      end

      describe "when using correct `addons:services` command" do
        it "displays all services" do
          stderr, stdout = execute("addons:services")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Slug                   Name  State
---------------------  ----  --------
cloudcounter:basic           alpha
cloudcounter:pro             public
cloudcounter:gold            public
cloudcounter:old             disabled
cloudcounter:platinum        beta

See plans with `heroku addons:plans SERVICE`
          STDOUT
        end
      end
    end

    describe 'v1-style command line params' do
      before do
        Excon.stub(method: :post, path: '/apps/example/addons') do
          { body: MultiJson.encode(addon), status: 201 }
        end
      end

      after do
        Excon.stubs.shift
      end

      it "understands foo=baz" do
        allow(@addons).to receive(:args).and_return(%w(my_addon foo=baz))

        allow(@addons.api).to receive(:request) { |params|
          expect(params[:body]).to include '"foo":"baz"'
        }.and_return(double(body: stringify(addon)))

        @addons.create
      end

      describe "addons:add" do
        before do
          Excon.stub(method: :get, path: '/apps/example/releases/current') do
            { body: MultiJson.dump({ 'name' => 'v99' }), status: 200 }
          end

          Excon.stub(method: :post, path: '/apps/example/addons/my_addon') do
            { body: MultiJson.encode(price: "free"), status: 200 }
          end
        end

        after do
          Excon.stubs.shift(2)
        end

        it "shows a deprecation warning about addon:add vs addons:create" do
          stderr, stdout = execute("addons:add my_addon --foo=bar extra=XXX")
          expect(stderr).to eq("")
          expect(stdout).to include "WARNING: `heroku addons:add` has been deprecated. Please use `heroku addons:create` instead."
        end

        it "shows a deprecation warning about non-unix params" do
          stderr, stdout = execute("addons:add my_addon --foo=bar extra=XXX")
          expect(stderr).to eq("")
          expect(stdout).to include "Warning: non-unix style params have been deprecated, use --extra=XXX instead"
        end
      end
    end

    describe 'unix-style command line params' do
      it "understands --foo=baz" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo=baz))

        allow(@addons).to receive(:request) { |args|
          expect(args[:body]).to include '"foo":"baz"'
        }.and_return(stringify(addon))

        @addons.create
      end

      it "understands --foo baz" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo baz))

        expect(@addons).to receive(:request) { |args|
          expect(args[:body]).to include '"foo":"baz"'
        }.and_return(stringify(addon))

        @addons.create
      end

      it "treats lone switches as true" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo))

        expect(@addons).to receive(:request) { |args|
          expect(args[:body]).to include '"foo":true'
        }.and_return(stringify(addon))

        @addons.create
      end

      it "converts 'true' to boolean" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo=true))

        expect(@addons).to receive(:request) { |args|
          expect(args[:body]).to include '"foo":true'
        }.and_return(stringify(addon))

        @addons.create
      end

      it "works with many config vars" do
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo  baz --bar  yes --baz=foo --bab --bob=true))

        expect(@addons).to receive(:request) { |args|
          expect(args[:body]).to include({ foo: 'baz', bar: 'yes', baz: 'foo', bab: true, bob: true }.to_json)
        }.and_return(stringify(addon))

        @addons.create
      end

      it "raises an error for spurious arguments" do
        allow(@addons).to receive(:args).and_return(%w(my_addon spurious))
        expect { @addons.create }.to raise_error(CommandFailed)
      end
    end

    describe "mixed options" do
      it "understands foo=bar and --baz=bar on the same line" do
        allow(@addons).to receive(:args).and_return(%w(my_addon foo=baz --baz=bar bob=true --bar))

        expect(@addons).to receive(:request) { |args|
          expect(args[:body]).to include '"foo":"baz"'
          expect(args[:body]).to include '"baz":"bar"'
          expect(args[:body]).to include '"bar":true'
          expect(args[:body]).to include '"bob":true'
        }.and_return(stringify(addon))

        @addons.create
      end

      it "sends the variables to the server" do
        Excon.stub(method: :post, path: '/apps/example/addons') do
          { body: MultiJson.encode(addon), status: 201 }
        end

        stderr, stdout = execute("addons:add my_addon foo=baz --baz=bar bob=true --bar")
        expect(stderr).to eq("")
        expect(stdout).to include("Warning: non-unix style params have been deprecated, use --foo=baz --bob=true instead")

        Excon.stubs.shift
      end
    end

    describe "fork, follow, and rollback switches" do
      it "should only resolve for heroku-postgresql addon" do
        %w{fork follow rollback}.each do |switch|
          allow(@addons).to receive(:args).and_return("addon --#{switch} HEROKU_POSTGRESQL_RED".split)

          allow(@addons).to receive(:request) { |args|
            expect(args[:body]).to include %("#{switch}":"HEROKU_POSTGRESQL_RED")
          }.and_return(stringify(addon))

          @addons.create
        end
      end

      it "should NOT translate --fork and --follow if passed in a full postgres url even if there are no databases" do
        %w{fork follow}.each do |switch|
          allow(@addons).to receive(:app_config_vars).and_return({})
          allow(@addons).to receive(:app_attachments).and_return([])
          allow(@addons).to receive(:args).and_return("heroku-postgresql:ronin --#{switch} postgres://foo:yeah@awesome.com:234/bestdb".split)

          allow(@addons).to receive(:request) { |args|
            expect(args[:body]).to include %("#{switch}":"postgres://foo:yeah@awesome.com:234/bestdb")
          }.and_return(stringify(addon))

          @addons.create
        end
      end

      # TODO: ?
      xit "should fail if fork / follow across applications and no plan is specified" do
        %w{fork follow}.each do |switch|
          allow(@addons).to receive(:app_config_vars).and_return({})
          allow(@addons).to receive(:app_attachments).and_return([])
          allow(@addons).to receive(:args).and_return("heroku-postgresql --#{switch} postgres://foo:yeah@awesome.com:234/bestdb".split)
          expect { @addons.create }.to raise_error(CommandFailed)
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
            :path => '/apps/example/releases/current'
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
        expect { @addons.create }.to raise_error(CommandFailed)
      end

      it "adds an addon" do
        allow(@addons).to receive(:args).and_return(%w(my_addon))

        allow(@addons).to receive(:request) { |args|
          expect(args[:path]).to eq "/apps/example/addons"
          expect(args[:body]).to include '"name":"my_addon"'
        }.and_return(stringify(addon))

        @addons.create
      end

      it "expands hgp:s0 to heroku-postgresql:standard-0" do
        allow(@addons).to receive(:args).and_return(%w(hpg:s0))

        allow(@addons).to receive(:request) { |args|
          expect(args[:path]).to eq "/apps/example/addons"
          expect(args[:body]).to include '"name":"heroku-postgresql:standard-0"'
        }.and_return(stringify(addon))

        @addons.create
      end

      it "adds an addon with a price" do
        Excon.stub(method: :post, path: '/apps/example/addons') do
          addon = build_addon(
            name:          "my_addon",
            addon_service: { name: "my_addon" },
            app:           { name: "example" })

          { body: MultiJson.encode(addon), status: 201 }
        end

        stderr, stdout = execute("addons:create my_addon")
        expect(stderr).to eq("")
        expect(stdout).to match /Creating my_addon... done/

        Excon.stubs.shift
      end

      it "adds an addon with a price and message" do
        Excon.stub(method: :post, path: '/apps/example/addons') do
          addon = build_addon(
            name:          "my_addon",
            addon_service: { name: "my_addon" },
            app:           { name: "example" }
          ).merge(provision_message: "OMG A MESSAGE", plan: { price: { 'cents' => 1000, 'unit' => 'month' }})

          { body: MultiJson.encode(addon), status: 201 }
        end

        stderr, stdout = execute("addons:create my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Creating my_addon... done, ($10.00/month)
Adding my_addon to example... done
OMG A MESSAGE
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT

        Excon.stubs.shift
      end

      it "excludes addon plan from docs message" do
        Excon.stub(method: :post, path: '/apps/example/addons') do
          addon = build_addon(
            name:          "my_addon",
            addon_service: { name: "my_addon" },
            app:           { name: "example" })

          { body: MultiJson.encode(addon), status: 201 }
        end

        stderr, stdout = execute("addons:create my_addon:test")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Creating my_addon... done, (free)
Adding my_addon to example... done
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT

        Excon.stubs.shift
      end

      it "adds an addon with a price and multiline message" do
        Excon.stub(method: :post, path: '/apps/example/addons') do
          addon = build_addon(
            name:          "my_addon",
            addon_service: { name: "my_addon" },
            app:           { name: "example" }
          ).merge(provision_message: "foo\nbar")

          { body: MultiJson.encode(addon), status: 201 }
        end

        stderr, stdout = execute("addons:create my_addon")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
Creating my_addon... done, (free)
Adding my_addon to example... done
foo
bar
Use `heroku addons:docs my_addon` to view documentation.
OUTPUT

        Excon.stubs.shift
      end

      it "displays an error with unexpected options" do
        expect(Heroku::Command).to receive(:error).with("Unexpected arguments: bar", false)
        run("addons:add redistogo -a foo bar")
      end
    end

    describe 'upgrading' do
      let(:addon) do
        build_addon(name: "my_addon",
          app:  { name: "example" },
          plan: { name: "my_addon" })
      end

      before do
        allow(@addons).to receive(:args).and_return(%w(my_addon))
        Excon.stub(
          {
            :expects => 200,
            :method => :get,
            :path => '/apps/example/releases/current'
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
        allow(@addons).to receive(:resolve_addon!).and_return(stringify(addon))
        allow(@addons).to receive(:args).and_return(%w(my_addon))

        expect(@addons.api).to receive(:request) { |args|
          expect(args[:method]).to eq :patch
          expect(args[:path]).to eq "/apps/example/addons/my_addon"
        }.and_return(OpenStruct.new(body: stringify(addon)))

        @addons.upgrade
      end

      # TODO: need this?
      xit "upgrade an addon with config vars" do
        allow(@addons).to receive(:resolve_addon!).and_return(stringify(addon))
        allow(@addons).to receive(:args).and_return(%w(my_addon --foo=baz))
        expect(@addons.heroku).to receive(:upgrade_addon).with('example', 'my_addon', { 'foo' => 'baz' })
        @addons.upgrade
      end

      it "upgrades an addon with a price" do
        my_addon = build_addon(
          name:          "my_addon",
          plan:          { name: "my_plan" },
          addon_service: { name: "my_service" },
          app:           { name: "example" },
          price:         { cents: 0, unit: "month" })

        Excon.stub(method: :get, path: '/apps/example/addons') do
          { body: MultiJson.encode([my_addon]), status: 200 }
        end

        Excon.stub(method: :get, path: '/apps/example/addons/my_service') do
          { body: MultiJson.encode(my_addon), status: 200 }
        end

        Excon.stub(method: :patch, path: '/apps/example/addons/my_addon') do
          { body: MultiJson.encode(my_addon), status: 200 }
        end

        stderr, stdout = execute("addons:upgrade my_service")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
WARNING: No add-on name specified (see `heroku help addons:upgrade`)
Finding add-on from service my_service on app example... done
Found my_addon (my_plan) on example.
Changing my_addon plan to my_service... done, (free)
OUTPUT

        Excon.stubs.shift(2)
      end

      it "adds an addon with a price and multiline message" do
        my_addon = build_addon(
          name:          "my_addon",
          plan:          { name: "my_plan" },
          addon_service: { name: "my_service" },
          app:           { name: "example" },
          price:         { cents: 0, unit: "month" }
        ).merge(provision_message: "foo\nbar")

        Excon.stub(method: :get, path: '/apps/example/addons') do
          { body: MultiJson.encode([my_addon]), status: 200 }
        end

        Excon.stub(method: :get, path: '/apps/example/addons/my_service') do
          { body: MultiJson.encode(my_addon), status: 200 }
        end

        Excon.stub(method: :patch, path: '/apps/example/addons/my_addon') do
          { body: MultiJson.encode(my_addon), status: 200 }
        end

        stderr, stdout = execute("addons:upgrade my_service")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-OUTPUT
WARNING: No add-on name specified (see `heroku help addons:upgrade`)
Finding add-on from service my_service on app example... done
Found my_addon (my_plan) on example.
Changing my_addon plan to my_service... done, (free)
foo
bar
OUTPUT

        Excon.stubs.shift(2)
      end

    end

    describe 'downgrading' do
      let(:addon) do
        build_addon(
          name:          "my_addon",
          addon_service: { name: "my_service" },
          plan:          { name: "my_plan" },
          app:           { name: "example" })
      end

      before do
        Excon.stub(
          { :expects => 200, :method => :get, :path => '/apps/example/releases/current' },
          { :body   => MultiJson.dump({ 'name' => 'v99' }), :status => 200, }
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
        allow(@addons).to receive(:args).and_return(%w(my_service low_plan))

        allow(@addons.api).to receive(:request) { |args|
          expect(args[:method]).to eq :patch
          expect(args[:path]).to eq "/apps/example/addons/my_service"
        }.and_return(OpenStruct.new(body: stringify(addon)))

        @addons.downgrade
      end

      it "downgrade an addon with config vars" do
        allow(@addons).to receive(:args).and_return(%w(my_service --foo=baz))

        allow(@addons.api).to receive(:request) { |args|
          expect(args[:method]).to eq :patch
          expect(args[:path]).to eq "/apps/example/addons/my_service"
        }.and_return(OpenStruct.new(body: stringify(addon)))

        @addons.downgrade
      end

      describe "console output" do
        before do
          my_addon = build_addon(
            name:          "my_addon",
            plan:          { name: "my_plan" },
            addon_service: { name: "my_service" },
            app:           { name: "example" })

          Excon.stub(method: :get, path: '/apps/example/addons') do
            { body: MultiJson.encode([my_addon]), status: 200 }
          end

          Excon.stub(method: :patch, path: '/apps/example/addons/my_service') do
            { body: MultiJson.encode(my_addon), status: 200 }
          end

          Excon.stub(method: :patch, path: '/apps/example/addons/my_addon') do
            { body: MultiJson.encode(my_addon), status: 200 }
          end
        end

        after do
          Excon.stubs.shift(2)
        end

        it "downgrades an addon with a price" do
          stderr, stdout = execute("addons:downgrade my_service low_plan")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-OUTPUT
Changing my_service plan to low_plan... done, (free)
OUTPUT
        end
      end
    end

    it "does not destroy addons with no confirm" do
      allow(@addons).to receive(:args).and_return(%w( addon1 ))
      allow(@addons).to receive(:resolve_addon!).and_return({"app" => { "name" => "example" }})
      expect(@addons).to receive(:confirm_command).once.and_return(false)
      expect(@addons.api).not_to receive(:request).with(hash_including(method: :delete))
      @addons.destroy
    end

    it "destroys addons after prompting for confirmation" do
      allow(@addons).to receive(:args).and_return(%w( addon1 ))
      expect(@addons).to receive(:confirm_command).once.and_return(true)
      allow(@addons).to receive(:get_attachments).and_return([])
      allow(@addons).to receive(:resolve_addon!).and_return({
        "id"          => "abc123",
        "config_vars" => [],
        "app"         => { "id" => "123", "name" => "example" }
      })

      allow(@addons.api).to receive(:request) { |args|
        expect(args[:path]).to eq "/apps/123/addons/abc123"
      }.and_return(OpenStruct.new(body: stringify(addon)))

      @addons.destroy
    end

    it "destroys addons with confirm option" do
      allow(Heroku::Command).to receive(:current_options).and_return(:confirm => "example")
      allow(@addons).to receive(:args).and_return(%w( addon1 ))
      allow(@addons).to receive(:get_attachments).and_return([])
      allow(@addons).to receive(:resolve_addon!).and_return({
        "id"          => "abc123",
        "config_vars" => [],
        "app"         => { "id" => "123", "name" => "example" }
      })

      allow(@addons.api).to receive(:request) { |args|
        expect(args[:path]).to eq "/apps/123/addons/abc123"
      }.and_return(OpenStruct.new(body: stringify(addon)))

      @addons.destroy
    end

    describe "opening add-on docs" do

      before(:each) do
        stub_core
        api.post_app("name" => "example", "stack" => "cedar")
        require "launchy"
        allow(Launchy).to receive(:open)
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
Opening redistogo docs... done
STDOUT
      end

      it "complains when many_per_app" do
        addon1 = stringify(addon.merge(name: "my_addon1", addon_service: { name: "my_service" }))
        addon2 = stringify(addon.merge(name: "my_addon2", addon_service: { name: "my_service_2" }))

        Excon.stub(method: :get, path: '/addon-services/thing') do
          { status: 404, body:'{}' }
        end
        Excon.stub(method: :get, path: '/apps/example/addons/thing') do
          { status: 404, body:'{}' }
        end

        Excon.stub(method: :get, path: '/addons/thing') do
          {
            status: 422,
            body: MultiJson.encode(
              id: "multiple_matches",
              message: "Ambiguous identifier; multiple matching add-ons found: my_addon1 (my_service), my_addon2 (my_service_2)."
            )
          }
        end

        expect { execute('addons:docs thing') }.to raise_error(Heroku::API::Errors::RequestFailed)
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
        Excon.stub(method: :get, path: %r'(/apps/example)?/addon-attachments/redistogo:nano') do
          {status: 404}
        end
        addon.merge!(addon_service: { name: "redistogo:nano" })

        allow_any_instance_of(Heroku::Command::Addons).to receive(:resolve_addon!).and_return(stringify(addon))
        require("launchy")
        expect(Launchy).to receive(:open).with("https://addons-sso.heroku.com/apps/example/addons/#{addon[:id]}").and_return(Thread.new {})
        stderr, stdout = execute('addons:open redistogo:nano')
        expect(stderr).to eq('')
        expect(stdout).to eq <<-STDOUT
Opening redistogo:nano (my_addon) for example... done
STDOUT
      end

      it "opens the addon using the attachment URL if a single unique attachment can be determined" do
        addon.merge!(addon_service: { name: "redistogo:nano" })
        attachment = build_attachment(
          name:  "REDISTOGO",
          addon: { name: "redistogo-angular", app: { name: "example" }},
          app:   { name: "example" })

        allow_any_instance_of(Heroku::Command::Addons).to receive(:resolve_addon!).and_return(stringify(addon))
        allow_any_instance_of(Heroku::Command::Addons).to receive(:get_attachment).and_return(stringify(attachment))
        require("launchy")
        expect(Launchy).to receive(:open).with("https://attachment-sso").and_return(Thread.new {})
        stderr, stdout = execute('addons:open redistogo:nano')
        expect(stderr).to eq('')
        expect(stdout).to eq <<-STDOUT
Opening redistogo:nano (my_addon) for example... done
STDOUT
      end

      it "opens the add-on using the add-on URL if a single unique attachment can not be determined" do
        Excon.stub(method: :get, path: '/apps/example/addon-attachments/redistogo:nano') do
          {
            status: 422,
            body: MultiJson.encode(
              id: "multiple_matches",
              message: "Ambiguous identifier; ..."
            )
          }
        end

        addon.merge!(addon_service: { name: "redistogo:nano" })

        allow_any_instance_of(Heroku::Command::Addons).to receive(:resolve_addon!).and_return(stringify(addon))
        require("launchy")
        expect(Launchy).to receive(:open).with("https://addons-sso.heroku.com/apps/example/addons/#{addon[:id]}").and_return(Thread.new {})
        stderr, stdout = execute('addons:open redistogo:nano')
        expect(stderr).to eq('')
        expect(stdout).to eq <<-STDOUT
Opening redistogo:nano (my_addon) for example... done
STDOUT
      end

      it "complains if no such addon exists" do
        Excon.stub(method: :get, path: %r'(/apps/example)?/addons/unknown') do
          { status: 404, body:'{"error": "hi"}' }
        end
        expect { execute('addons:open unknown') }.to raise_error(Heroku::API::Errors::NotFound)
      end

      it "complains if addon is not installed" do
        Excon.stub(method: :get, path: %r'(/apps/example)?/addons/deployhooks:http') do
          { status: 404, body:'{"error": "hi"}' }
        end
        expect { execute('addons:open deployhooks:http') }.to raise_error(Heroku::API::Errors::NotFound)
      end
    end

  end
end
