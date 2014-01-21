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
      lambda { execute("ps:dynos") }.should raise_error(Heroku::Command::CommandFailed, "For Cedar apps, use `heroku ps`")
    end

    it "ps:workers errors out on cedar apps" do
      lambda { execute("ps:workers") }.should raise_error(Heroku::Command::CommandFailed, "For Cedar apps, use `heroku ps`")
    end

    describe "ps" do

      it "displays processes" do
        Heroku::Command::Ps.any_instance.should_receive(:time_ago).exactly(10).times.and_return("2012/09/11 12:34:56 (~ 0s ago)")
        api.post_ps_scale('example', 'web', 10)
        stderr, stdout = execute("ps")
        stderr.should == ""
        stdout.should == <<-STDOUT
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
        Heroku::Command::Ps.any_instance.should_receive(:time_ago).and_return('2012/09/11 12:34:56 (~ 0s ago)', '2012/09/11 12:34:56 (~ 0s ago)')
        api.post_ps "example", "bash"

        stderr, stdout = execute("ps")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== run: one-off processes
run.1 (1X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`

=== web (1X): `bundle exec thin start -p $PORT`
web.1: created 2012/09/11 12:34:56 (~ 0s ago)

STDOUT
      end

      it "displays 2X sizes" do
        Heroku::Command::Ps.any_instance.should_receive(:time_ago).and_return("2012/09/11 12:34:56 (~ 0s ago)")
        api.put_formation('example', 'web' => '2')

        stderr, stdout = execute("ps")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== web (2X): `bundle exec thin start -p $PORT`
web.1: created 2012/09/11 12:34:56 (~ 0s ago)

STDOUT
      end

      it "displays PX sizes" do
        Heroku::Command::Ps.any_instance.should_receive(:time_ago).and_return("2012/09/11 12:34:56 (~ 0s ago)")
        api.put_formation('example', 'web' => 'P')

        stderr, stdout = execute("ps")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== web (PX): `bundle exec thin start -p $PORT`
web.1: created 2012/09/11 12:34:56 (~ 0s ago)

STDOUT
      end

      it "displays multiple sizes for one-offs" do
        Heroku::Command::Ps.any_instance.should_receive(:time_ago).exactly(5).times.and_return("2012/09/11 12:34:56 (~ 0s ago)")
        api.post_ps('example', 'bash', 'size' => "P")
        api.post_ps('example', 'bash', 'size' => 2)
        api.post_ps('example', 'bash', 'size' => "4")
        api.post_ps('example', 'bash')
        stderr, stdout = execute("ps")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== run: one-off processes
run.1 (PX): created 2012/09/11 12:34:56 (~ 0s ago): `bash`
run.2 (2X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`
run.3 (4X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`
run.4 (1X): created 2012/09/11 12:34:56 (~ 0s ago): `bash`

=== web (1X): `bundle exec thin start -p $PORT`
web.1: created 2012/09/11 12:34:56 (~ 0s ago)

STDOUT

      end

    end

    describe "ps:restart" do

      it "restarts all dynos with no args" do
        stderr, stdout = execute("ps:restart")
        stderr.should == ""
        stdout.should == <<-STDOUT
Restarting dynos... done
STDOUT
      end

      it "restarts one dyno" do
        stderr, stdout = execute("ps:restart web.1")
        stderr.should == ""
        stdout.should == <<-STDOUT
Restarting web.1 dyno... done
STDOUT
      end

      it "restarts a type of dyno" do
        stderr, stdout = execute("ps:restart web")
        stderr.should == ""
        stdout.should == <<-STDOUT
Restarting web dynos... done
STDOUT
      end

    end

    describe "ps:scale" do

      it "can scale using key/value format" do
        Excon.stub({ :method => :patch, :path => "/apps/example/formation" },
                   { :body => [{"quantity" => "5", "size" => "1", "type" => "web"}],
                     :status => 200})
        stderr, stdout = execute("ps:scale web=5")
        stderr.should == ""
        stdout.should == <<-STDOUT
Scaling dynos... done, now running web at 5:1X.
STDOUT
      end

      it "can scale relative amounts" do
        Excon.stub({ :method => :patch, :path => "/apps/example/formation" },
                   { :body => [{"quantity" => "3", "size" => "1", "type" => "web"}],
                     :status => 200})
        stderr, stdout = execute("ps:scale web+2")
        stderr.should == ""
        stdout.should == <<-STDOUT
Scaling dynos... done, now running web at 3:1X.
STDOUT
      end

      it "can resize while scaling" do
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [{"process" => "web", "quantity" => "4", "size" => "2"}]
            }.to_json
          },
          :body => [{"quantity" => 4, "size" => 2, "type" => "web"}],
          :status => 200
        )
        stderr, stdout = execute("ps:scale web=4:2X")
        stderr.should == ""
        stdout.should == <<-STDOUT
Scaling dynos... done, now running web at 4:2X.
STDOUT
      end

      it "can scale multiple types in one call" do
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [
                {"process" => "web",    "quantity" => "4", "size" => "1"},
                {"process" => "worker", "quantity" => "2", "size" => "2"},
              ]
            }.to_json
          },
          :body => [
            {"quantity" => 4, "size" => 1, "type" => "web"},
            {"quantity" => 2, "size" => 2, "type" => "worker"},
            {"quantity" => 0, "size" => 1, "type" => "dummy"}
          ],
          :status => 200
        )
        stderr, stdout = execute("ps:scale web=4:1X worker=2:2X")
        stderr.should == ""
        stdout.should == <<-STDOUT
Scaling dynos... done, now running web at 4:1X, worker at 2:2X.
STDOUT
      end

      it "accepts P as a valid size" do
        Excon.stub(
          {
            :method => :patch, :path => "/apps/example/formation",
            :body => {
              "updates" => [{"process" => "web", "quantity" => "4", "size" => "P"}]
            }.to_json
          },
          :body => [{"quantity" => 4, "size" => "P", "type" => "web"}],
          :status => 200
        )
        stderr, stdout = execute("ps:scale web=4:PX")
        stderr.should == ""
        stdout.should == <<-STDOUT
Scaling dynos... done, now running web at 4:PX.
STDOUT
      end
    end

    describe "ps:resize" do

      it "can resize using a key/value format" do
        stderr, stdout = execute("ps:resize web=2X")
        stderr.should == ""
        stdout.should == <<-STDOUT
Resizing and restarting the specified dynos... done
web dynos now 2X ($0.10/dyno-hour)
STDOUT
      end

      it "can resize multiple types in one call" do
        stderr, stdout = execute("ps:resize web=4x worker=2X")
        stderr.should == ""
        stdout.should == <<-STDOUT
Resizing and restarting the specified dynos... done
web dynos now 4X ($0.20/dyno-hour)
worker dynos now 2X ($0.10/dyno-hour)
STDOUT
      end

      it "accepts P as a valid size, with a price of $0.80/hour" do
        stderr, stdout = execute("ps:resize web=PX worker=Px")
        stderr.should == ""
        stdout.should == <<-STDOUT
Resizing and restarting the specified dynos... done
web dynos now PX ($0.80/dyno-hour)
worker dynos now PX ($0.80/dyno-hour)
STDOUT
      end

    end

    describe "ps:stop" do

      it "restarts one dyno" do
        stderr, stdout = execute("ps:restart ps.1")
        stderr.should == ""
        stdout.should == <<-STDOUT
Restarting ps.1 dyno... done
STDOUT
      end

      it "restarts a type of dyno" do
        stderr, stdout = execute("ps:restart ps")
        stderr.should == ""
        stdout.should == <<-STDOUT
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
        stderr.should == ""
        stdout.should == <<-STDOUT
~ `heroku ps:dynos QTY` has been deprecated and replaced with `heroku ps:scale dynos=QTY`
example is running 0 dynos
STDOUT
      end

      it "sets the number of dynos" do
        stderr, stdout = execute("ps:dynos 5")
        stderr.should == ""
        stdout.should == <<-STDOUT
~ `heroku ps:dynos QTY` has been deprecated and replaced with `heroku ps:scale dynos=QTY`
Scaling dynos... done, now running 5
STDOUT
      end

    end

    describe "ps:workers" do

      it "displays the current number of workers" do
        stderr, stdout = execute("ps:workers")
        stderr.should == ""
        stdout.should == <<-STDOUT
~ `heroku ps:workers QTY` has been deprecated and replaced with `heroku ps:scale workers=QTY`
example is running 0 workers
STDOUT
      end

      it "sets the number of workers" do
        stderr, stdout = execute("ps:workers 5")
        stderr.should == ""
        stdout.should == <<-STDOUT
~ `heroku ps:workers QTY` has been deprecated and replaced with `heroku ps:scale workers=QTY`
Scaling workers... done, now running 5
STDOUT
      end

    end

  end

end
