require "spec_helper"
require "heroku/command/ps"

describe Heroku::Command::Ps do

  before(:each) do
    stub_core
  end

  context("cedar") do

    before(:each) do
      api.post_app("name" => "example", "stack" => "cedar")
    end

    after(:each) do
      api.delete_app("example")
    end

    it "ps:dynos errors out on cedar apps" do
      expect { execute("ps:dynos") }.to raise_error(Heroku::Command::CommandFailed, "For Cedar apps, use `heroku ps`")
    end

    it "ps:workers errors out on cedar apps" do
      expect { execute("ps:workers") }.to raise_error(Heroku::Command::CommandFailed, "For Cedar apps, use `heroku ps`")
    end

    describe "ps" do

      it "displays processes" do
        Excon.stub(
          { :method => :get, :path => "/apps/example/dynos" },
          :body => 10.times.map do |i|
            {
              "size"       => "1X",
              "updated_at" => "2012-09-11T12:34:56Z",
              "command"    => "bundle exec thin start -p $PORT",
              "created_at" => "2012-09-11T12:30:56Z",
              "id"         => "a94d0fa2-8509-4dab-8742-be7bfe768ecc",
              "name"       => "web.#{i+1}",
              "state"      => "created",
              "type"       => "web"
            }
          end.to_json,
          :status => 200
        )
        Excon.stub(
          { :method => :post, :path => "/apps/example/actions/get-quota" },
            :status => 404
        )
        expect_any_instance_of(Heroku::Command::Ps).to receive(:time_ago).exactly(10).times.and_return("2012/09/11 12:34:56 (~ 0s ago)")
        stderr, stdout = execute("ps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== web (1X): `bundle exec thin start -p $PORT`
web.1: created 2012/09/11 12:34:56 (~ 0s ago)
web.2: created 2012/09/11 12:34:56 (~ 0s ago)
web.3: created 2012/09/11 12:34:56 (~ 0s ago)
web.4: created 2012/09/11 12:34:56 (~ 0s ago)
web.5: created 2012/09/11 12:34:56 (~ 0s ago)
web.6: created 2012/09/11 12:34:56 (~ 0s ago)
web.7: created 2012/09/11 12:34:56 (~ 0s ago)
web.8: created 2012/09/11 12:34:56 (~ 0s ago)
web.9: created 2012/09/11 12:34:56 (~ 0s ago)
web.10: created 2012/09/11 12:34:56 (~ 0s ago)

STDOUT
      end

      it "displays one-off processes" do
        Excon.stub(
          { :method => :get, :path => "/apps/example/dynos" },
          :body => 2.times.map do |i|
            {
              "size"       => "1X",
              "updated_at" => "2012-09-11T12:34:56Z",
              "command"    => "bash",
              "created_at" => "2012-09-11T12:30:56Z",
              "id"         => "a94d0fa2-8509-4dab-8742-be7bfe768ecc",
              "name"       => "run.#{i+1}",
              "state"      => "created",
              "type"       => "run"
            }
          end.to_json,
          :status => 200
        )
        Excon.stub(
          { :method => :post, :path => "/apps/example/actions/get-quota" },
            :status => 404
        )
        expect_any_instance_of(Heroku::Command::Ps).to receive(:time_ago).twice.and_return('2012/09/11 12:34:56 (~ 0s ago)')
        stderr, stdout = execute("ps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== run: one-off processes
run.1 (1X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`
run.2 (1X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`

STDOUT
      end

      it "displays 2X sizes" do
        Excon.stub(
          { :method => :get, :path => "/apps/example/dynos" },
          :body => 2.times.map do |i|
            {
              "size"       => "2X",
              "updated_at" => "2012-09-11T12:34:56Z",
              "command"    => "bundle exec thin start -p $PORT",
              "created_at" => "2012-09-11T12:30:56Z",
              "id"         => "a94d0fa2-8509-4dab-8742-be7bfe768ecc",
              "name"       => "web.#{i+1}",
              "state"      => "created",
              "type"       => "web"
            }
          end.to_json,
          :status => 200
        )
        Excon.stub(
          { :method => :post, :path => "/apps/example/actions/get-quota" },
            :status => 404
        )
        expect_any_instance_of(Heroku::Command::Ps).to receive(:time_ago).twice.and_return("2012/09/11 12:34:56 (~ 0s ago)")

        stderr, stdout = execute("ps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== web (2X): `bundle exec thin start -p $PORT`
web.1: created 2012/09/11 12:34:56 (~ 0s ago)
web.2: created 2012/09/11 12:34:56 (~ 0s ago)

STDOUT
      end

      it "displays PX sizes" do
        Excon.stub(
          { :method => :get, :path => "/apps/example/dynos" },
          :body => 2.times.map do |i|
            {
              "size"       => "PX",
              "updated_at" => "2012-09-11T12:34:56Z",
              "command"    => "bundle exec thin start -p $PORT",
              "created_at" => "2012-09-11T12:30:56Z",
              "id"         => "a94d0fa2-8509-4dab-8742-be7bfe768ecc",
              "name"       => "web.#{i+1}",
              "state"      => "created",
              "type"       => "web"
            }
          end.to_json,
          :status => 200
        )
        Excon.stub(
          { :method => :post, :path => "/apps/example/actions/get-quota" },
            :status => 404
        )
        expect_any_instance_of(Heroku::Command::Ps).to receive(:time_ago).twice.and_return("2012/09/11 12:34:56 (~ 0s ago)")

        stderr, stdout = execute("ps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== web (PX): `bundle exec thin start -p $PORT`
web.1: created 2012/09/11 12:34:56 (~ 0s ago)
web.2: created 2012/09/11 12:34:56 (~ 0s ago)

STDOUT
      end

      it "displays multiple sizes for one-offs" do
        sizes = ["PX", "2X", "4X", "1X"]
        Excon.stub(
          { :method => :get, :path => "/apps/example/dynos" },
          :body => 4.times.map do |i|
            {
              "size"       => sizes[i],
              "updated_at" => "2012-09-11T12:34:56Z",
              "command"    => "bash",
              "created_at" => "2012-09-11T12:30:56Z",
              "id"         => "a94d0fa2-8509-4dab-8742-be7bfe768ecc",
              "name"       => "run.#{i+1}",
              "state"      => "created",
              "type"       => "run"
            }
          end.to_json,
          :status => 200
        )
        Excon.stub(
          { :method => :post, :path => "/apps/example/actions/get-quota" },
            :status => 404
        )
        expect_any_instance_of(Heroku::Command::Ps).to receive(:time_ago).exactly(4).times.and_return("2012/09/11 12:34:56 (~ 0s ago)")
        stderr, stdout = execute("ps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== run: one-off processes
run.1 (PX): created 2012/09/11 12:34:56 (~ 0s ago): `bash`
run.2 (2X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`
run.3 (4X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`
run.4 (1X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`

STDOUT

      end

    end

    it "displays how much run-time is left if the application has quota (seconds)" do
      allow_until = (Time.now + 30).getutc
      Excon.stub(
          { :method => :get, :path => "/apps/example/dynos" },
          :body => 1.times.map do |i|
            {
              "size"       => "1X",
              "updated_at" => "2012-09-11T12:34:56Z",
              "command"    => "bundle exec thin start -p $PORT",
              "created_at" => "2012-09-11T12:30:56Z",
              "id"         => "a94d0fa2-8509-4dab-8742-be7bfe768ecc",
              "name"       => "web.#{i+1}",
              "state"      => "up",
              "type"       => "web"
            }
          end.to_json,
          :status => 200
        )
        Excon.stub(
          { :method => :post, :path => "/apps/example/actions/get-quota" },
          :body =>
            {
              "allow_until"       => allow_until.iso8601,
              "deny_until"        => nil,
            }.to_json,
          :status => 200
        )
        expect_any_instance_of(Heroku::Command::Ps).to receive(:time_ago).once.times.and_return("2012/09/11 12:34:56 (~ 0s ago)")
        expect_any_instance_of(Heroku::Command::Ps).to receive(:time_remaining).and_return("20s")
        stderr, stdout = execute("ps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Free quota left: 20s
=== web (1X): `bundle exec thin start -p $PORT`
web.1: up 2012/09/11 12:34:56 (~ 0s ago)

STDOUT
    end

    describe "ps:restart" do

      it "restarts all dynos with no args" do
        stderr, stdout = execute("ps:restart")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Restarting dynos... done
STDOUT
      end

      it "restarts one dyno" do
        stderr, stdout = execute("ps:restart web.1")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Restarting web.1 dyno... done
STDOUT
      end

      it "restarts a type of dyno" do
        stderr, stdout = execute("ps:restart web")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Restarting web dynos... done
STDOUT
      end

    end

    describe "ps:scale" do

      it "can scale using key/value format" do
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: [], status: 200})
        Excon.stub({ :method => :patch, :path => "/apps/example/formation" },
                   { :body => [{"quantity" => "5", "size" => "1X", "type" => "web"}],
                     :status => 200})
        stderr, stdout = execute("ps:scale web=5")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Scaling dynos... done, now running web at 5:1X.
STDOUT
      end

      it "can scale relative amounts" do
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: [], status: 200})
        Excon.stub({ :method => :patch, :path => "/apps/example/formation" },
                   { :body => [{"quantity" => "3", "size" => "1X", "type" => "web"}],
                     :status => 200})
        stderr, stdout = execute("ps:scale web+2")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Scaling dynos... done, now running web at 3:1X.
STDOUT
      end

      it "can resize while scaling" do
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: [], status: 200})
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [{"type" => "web", "quantity" => 4, "size" => "2X"}]
            }.to_json
          },
          :body => [{"quantity" => 4, "size" => "2X", "type" => "web"}],
          :status => 200
        )
        stderr, stdout = execute("ps:scale web=4:2X")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Scaling dynos... done, now running web at 4:2X.
STDOUT
      end

      it "can scale multiple types in one call" do
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: [], status: 200})
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [
                {"type" => "web",    "quantity" => 4, "size" => "1X"},
                {"type" => "worker", "quantity" => 2, "size" => "2x"},
              ]
            }.to_json
          },
          :body => [
            {"quantity" => 4, "size" => "1X", "type" => "web"},
            {"quantity" => 2, "size" => "2X", "type" => "worker"},
            {"quantity" => 0, "size" => "1X", "type" => "dummy"}
          ],
          :status => 200
        )
        stderr, stdout = execute("ps:scale web=4:1X worker=2:2x")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Scaling dynos... done, now running web at 4:1X, worker at 2:2X.
STDOUT
      end

      it "accepts PX as a valid size" do
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: [], status: 200})
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [{"type" => "web", "quantity" => 4, "size" => "PX"}]
            }.to_json
          },
          :body => [{"quantity" => 4, "size" => "PX", "type" => "web"}],
          :status => 200
        )
        stderr, stdout = execute("ps:scale web=4:PX")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Scaling dynos... done, now running web at 4:PX.
STDOUT
      end
    end

    describe "ps:resize" do

      it "can resize using a key/value format" do
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: [{"type" => "web", "size" => "1X", "quantity" => 1}], status: 200})
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [{"type" => "web", "size" => "2X", "quantity" => 1}]
            }.to_json
          },
          :body => [{"quantity" => 2, "size" => "2X", "type" => "web"}],
          :status => 200
        )
        stderr, stdout = execute("ps:resize web=2X")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
dyno  type  qty  cost/mo
----  ----  ---  -------
web     1X    1       36
STDOUT
      end

      it "can resize multiple types in one call" do
        formation = [
          {"type" => "web", "size" => "1X", "quantity" => 1},
          {"type" => "worker", "size" => "1X", "quantity" => 1},
        ]
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: formation, status: 200})
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [
                {"type" => "web", "size" => "4x", "quantity" => 1},
                {"type" => "worker", "size" => "2X", "quantity" => 1}
              ]
            }.to_json
          },
          :body => [
            {"quantity" => 2, "size" => "1X", "type" => "web"},
            {"quantity" => 1, "size" => "2X", "type" => "worker"}
          ],
          :status => 200
        )
        stderr, stdout = execute("ps:resize web=4x worker=2X")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
dyno    type  qty  cost/mo
------  ----  ---  -------
web       1X    1       36
worker    1X    1       36
STDOUT
      end

      it "accepts PX as a valid size, with a price of $0.80/hour" do
        formation = [
          {"type" => "web", "size" => "1X", "quantity" => 1},
          {"type" => "worker", "size" => "1X", "quantity" => 1},
        ]
        Excon.stub({ method: :get, path: "/apps/example/formation" }, { body: formation, status: 200})
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [
                {"type" => "web", "size" => "PX", "quantity" => 1},
                {"type" => "worker", "size" => "Px", "quantity" => 1}
              ]
            }.to_json
          },
          :body => [
            {"quantity" => 2, "size" => "PX", "type" => "web"},
            {"quantity" => 1, "size" => "PX", "type" => "worker"}
          ],
          :status => 200
        )
        stderr, stdout = execute("ps:resize web=PX worker=Px")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
dyno    type  qty  cost/mo
------  ----  ---  -------
web       1X    1       36
worker    1X    1       36
STDOUT
      end

    end

    describe "ps:stop" do

      it "restarts one dyno" do
        stderr, stdout = execute("ps:restart ps.1")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Restarting ps.1 dyno... done
STDOUT
      end

      it "restarts a type of dyno" do
        stderr, stdout = execute("ps:restart ps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Restarting ps dynos... done
STDOUT
      end

    end

  end

  context("non-cedar") do

    before(:each) do
      api.post_app("name" => "example")
    end

    after(:each) do
      api.delete_app("example")
    end

    describe "ps:dynos" do

      it "displays the current number of dynos" do
        stderr, stdout = execute("ps:dynos")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
~ `heroku ps:dynos QTY` has been deprecated and replaced with `heroku ps:scale dynos=QTY`
example is running 0 dynos
STDOUT
      end

      it "sets the number of dynos" do
        stderr, stdout = execute("ps:dynos 5")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
~ `heroku ps:dynos QTY` has been deprecated and replaced with `heroku ps:scale dynos=QTY`
Scaling dynos... done, now running 5
STDOUT
      end

    end

    describe "ps:workers" do

      it "displays the current number of workers" do
        stderr, stdout = execute("ps:workers")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
~ `heroku ps:workers QTY` has been deprecated and replaced with `heroku ps:scale workers=QTY`
example is running 0 workers
STDOUT
      end

      it "sets the number of workers" do
        stderr, stdout = execute("ps:workers 5")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
~ `heroku ps:workers QTY` has been deprecated and replaced with `heroku ps:scale workers=QTY`
Scaling workers... done, now running 5
STDOUT
      end

    end

  end

end
