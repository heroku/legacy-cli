require File.expand_path("./base", File.dirname(__FILE__))
require "cgi"
require "heroku/client"

describe Heroku::Client do
  before do
    @client = Heroku::Client.new(nil, nil)
    @resource = mock('heroku rest resource')
    @client.stub!(:extract_warning)
  end

  it "list -> get a list of this user's apps" do
    stub_api_request(:get, "/apps").to_return(:body => <<-EOXML)
      <?xml version='1.0' encoding='UTF-8'?>
      <apps type="array">
        <app><name>myapp1</name><owner>test@heroku.com</owner></app>
        <app><name>myapp2</name><owner>test@heroku.com</owner></app>
      </apps>
    EOXML
    @client.list.should == [
      ["myapp1", "test@heroku.com"],
      ["myapp2", "test@heroku.com"]
    ]
  end

  it "info -> get app attributes" do
    stub_api_request(:get, "/apps/myapp").to_return(:body => <<-EOXML)
      <?xml version='1.0' encoding='UTF-8'?>
      <app>
        <blessed type='boolean'>true</blessed>
        <created-at type='datetime'>2008-07-08T17:21:50-07:00</created-at>
        <id type='integer'>49134</id>
        <name>myapp</name>
        <production type='boolean'>true</production>
        <share-public type='boolean'>true</share-public>
        <domain_name/>
      </app>
    EOXML
    @client.stub!(:list_collaborators).and_return([:jon, :mike])
    @client.stub!(:installed_addons).and_return([:addon1])
    @client.info('myapp').should == { :blessed => 'true', :created_at => '2008-07-08T17:21:50-07:00', :id => '49134', :name => 'myapp', :production => 'true', :share_public => 'true', :domain_name => nil, :collaborators => [:jon, :mike], :addons => [:addon1] }
  end

  it "create_request -> create a new blank app" do
    stub_api_request(:post, "/apps").with(:body => "").to_return(:body => <<-EOXML)
      <?xml version="1.0" encoding="UTF-8"?>
      <app><name>untitled-123</name></app>
    EOXML
    @client.create_request.should == "untitled-123"
  end

  it "create_request(name) -> create a new blank app with a specified name" do
    stub_api_request(:post, "/apps").with(:body => "app[name]=newapp").to_return(:body => <<-EOXML)
      <?xml version="1.0" encoding="UTF-8"?>
      <app><name>newapp</name></app>
    EOXML
    @client.create_request("newapp").should == "newapp"
  end

  it "create_complete?(name) -> checks if a create request is complete" do
    @response = mock('response')
    @response.should_receive(:code).and_return(202)
    @client.should_receive(:resource).with('/apps/myapp/status').and_return(@resource)
    @resource.should_receive(:put).with({}, @client.heroku_headers).and_return(@response)
    @client.create_complete?('myapp').should be_false
  end

  it "update(name, attributes) -> updates existing apps" do
    stub_api_request(:put, "/apps/myapp").with(:body => "app[mode]=production")
    @client.update("myapp", :mode => 'production')
  end

  it "destroy(name) -> destroy the named app" do
    stub_api_request(:delete, "/apps/destroyme")
    @client.destroy("destroyme")
  end

  it "rake(app_name, cmd) -> run a rake command on the app" do
    stub_api_request(:post, "/apps/myapp/services").with(:body => "rake db:migrate").to_return(:body => "foo")
    stub_api_request(:get,  "/foo").to_return(:body => "output")
    @client.rake('myapp', 'db:migrate')
  end

  it "console(app_name, cmd) -> run a console command on the app" do
    stub_api_request(:post, "/apps/myapp/console").with(:body => "2+2")
    @client.console('myapp', '2+2')
  end

  it "console(app_name) { |c| } -> opens a console session, yields one accessor and closes it after the block" do
    stub_api_request(:post,   "/apps/myapp/consoles").to_return(:body => "consolename")
    stub_api_request(:post,   "/apps/myapp/consoles/consolename/command").with(:body => "1+1").to_return(:body => "2")
    stub_api_request(:delete, "/apps/myapp/consoles/consolename")

    @client.console('myapp') do |c|
      c.run("1+1").should == '=> 2'
    end
  end

  it "console displays xml-formatted errors properly" do
    stub_api_request(:post, "/apps/myapp/console").with(:body => 'test').to_return(:status => 422, :body => '<?xml version="1.0"?><errors><error>Test Error</error></errors>')
    @client.console('myapp', 'test').should == ' !   Test Error'
  end

  it "console returns the response body of a failed request" do
    stub_request(:post, %r{.*/apps/myapp/console}).to_return({
      :body => "ERRMSG", :status => 502
    })
    lambda { @client.console('myapp') }.should raise_error(Heroku::Client::AppCrashed, "ERRMSG")
  end

  it "restart(app_name) -> restarts the app servers" do
    stub_api_request(:delete, "/apps/myapp/server")
    @client.restart('myapp')
  end

  it "logs(app_name) -> returns recent output of the app logs" do
    stub_api_request(:get, "/apps/myapp/logs").to_return(:body => "log")
    @client.logs('myapp').should == 'log'
  end

  it "cron_logs(app_name) -> returns recent output of the app logs" do
    stub_api_request(:get, "/apps/myapp/cron_logs").to_return(:body => "cron log")
    @client.cron_logs('myapp').should == 'cron log'
  end

  it "set_dynos(app_name, qty) -> scales the app" do
    stub_api_request(:put, "/apps/myapp/dynos").with(:body => "dynos=3")
    @client.set_dynos('myapp', 3)
  end

  it "rake catches 502s and shows the app crashlog" do
    e = RestClient::RequestFailed.new
    e.stub!(:http_code).and_return(502)
    e.stub!(:http_body).and_return('the crashlog')
    @client.should_receive(:post).and_raise(e)
    lambda { @client.rake('myapp', '') }.should raise_error(Heroku::Client::AppCrashed)
  end

  it "rake passes other status codes (i.e., 500) as standard restclient exceptions" do
    e = RestClient::RequestFailed.new
    e.stub!(:http_code).and_return(500)
    e.stub!(:http_body).and_return('not a crashlog')
    @client.should_receive(:post).and_raise(e)
    lambda { @client.rake('myapp', '') }.should raise_error(RestClient::RequestFailed)
  end

  describe "bundles" do
    it "gives a temporary URL where the bundle can be downloaded" do
      stub_api_request(:get, "/apps/myapp/bundles/latest").to_return(:body => "{\"name\":\"bundle1\",\"temporary_url\":\"https:\\/\\/s3.amazonaws.com\\/herokubundles\\/123.tar.gz\"}")
      @client.bundle_url('myapp').should == 'https://s3.amazonaws.com/herokubundles/123.tar.gz'
    end
  end

  describe "collaborators" do
    it "list(app_name) -> list app collaborators" do
      stub_api_request(:get, "/apps/myapp/collaborators").to_return(:body => <<-EOXML)
        <?xml version="1.0" encoding="UTF-8"?>
        <collaborators type="array">
          <collaborator><email>joe@example.com</email></collaborator>
          <collaborator><email>jon@example.com</email></collaborator>
        </collaborators>
      EOXML
      @client.list_collaborators('myapp').should == [
        { :email => 'joe@example.com' },
        { :email => 'jon@example.com' }
      ]
    end

    it "add_collaborator(app_name, email) -> adds collaborator to app" do
      stub_api_request(:post, "/apps/myapp/collaborators").with(:body => "collaborator%5Bemail%5D=joe%40example.com")
      @client.add_collaborator('myapp', 'joe@example.com')
    end

    it "add_collaborator returns the response body of a failed request" do
      stub_request(:post, %r{.*/apps/myapp/collaborators}).to_return({
        :body => "ERRMSG", :status => 422
      })
      @client.add_collaborator('myapp', 'joe@example.com').to_s.should == "ERRMSG"
    end

    it "remove_collaborator(app_name, email) -> removes collaborator from app" do
      stub_api_request(:delete, "/apps/myapp/collaborators/joe%40example%2Ecom")
      @client.remove_collaborator('myapp', 'joe@example.com')
    end
  end

  describe "domain names" do
    it "list(app_name) -> list app domain names" do
      stub_api_request(:get, "/apps/myapp/domains").to_return(:body => <<-EOXML)
        <?xml version="1.0" encoding="UTF-8"?>
        <domain-names type="array">
          <domain-name><domain>example1.com</domain></domain-name>
          <domain-name><domain>example2.com</domain></domain-name>
        </domain-names>
      EOXML
      @client.list_domains('myapp').should == [{:domain => 'example1.com'}, {:domain => 'example2.com'}]
    end

    it "add_domain(app_name, domain) -> adds domain name to app" do
      stub_api_request(:post, "/apps/myapp/domains").with(:body => "example.com")
      @client.add_domain('myapp', 'example.com')
    end

    it "remove_domain(app_name, domain) -> removes domain name from app" do
      stub_api_request(:delete, "/apps/myapp/domains/example.com")
      @client.remove_domain('myapp', 'example.com')
    end

    it "remove_domains(app_name) -> removes all domain names from app" do
      stub_api_request(:delete, "/apps/myapp/domains")
      @client.remove_domains('myapp')
    end

    it "add_ssl(app_name, pem, key) -> adds a ssl cert to the domain" do
      stub_api_request(:post, "/apps/myapp/ssl").with do |request|
        body = CGI::parse(request.body)
        body["key"].first.should == "thekey"
        body["pem"].first.should == "thepem"
      end.to_return(:body => "{}")
      @client.add_ssl('myapp', 'thepem', 'thekey')
    end

    it "remove_ssl(app_name, domain) -> removes the ssl cert for the domain" do
      stub_api_request(:delete, "/apps/myapp/domains/example.com/ssl")
      @client.remove_ssl('myapp', 'example.com')
    end
  end

  describe "ssh keys" do
    it "fetches a list of the user's current keys" do
      stub_api_request(:get, "/user/keys").to_return(:body => <<-EOXML)
        <?xml version="1.0" encoding="UTF-8"?>
        <keys type="array">
          <key>
            <contents>ssh-dss thekey== joe@workstation</contents>
          </key>
        </keys>
      EOXML
      @client.keys.should == [ "ssh-dss thekey== joe@workstation" ]
    end

    it "add_key(key) -> add an ssh key (e.g., the contents of id_rsa.pub) to the user" do
      stub_api_request(:post, "/user/keys").with(:body => "a key")
      @client.add_key('a key')
    end

    it "remove_key(key) -> remove an ssh key by name (user@box)" do
      stub_api_request(:delete, "/user/keys/joe%40workstation")
      @client.remove_key('joe@workstation')
    end

    it "remove_all_keys -> removes all ssh keys for the user" do
      stub_api_request(:delete, "/user/keys")
      @client.remove_all_keys
    end

    it "database_session(app_name) -> creates a taps database session" do
      module ::Taps
        def self.version
          "0.3.0"
        end
      end

      stub_api_request(:post, "/apps/myapp/database/session2").to_return(:body => "{\"session_id\":\"x234\"}")
      @client.database_session('myapp')
    end

    it "database_reset(app_name) -> reset an app's database" do
      stub_api_request(:post, "/apps/myapp/database/reset")
      @client.database_reset('myapp')
    end

    it "maintenance(app_name, :on) -> sets maintenance mode for an app" do
      stub_api_request(:post, "/apps/myapp/server/maintenance").with(:body => "maintenance_mode=1")
      @client.maintenance('myapp', :on)
    end

    it "maintenance(app_name, :off) -> turns off maintenance mode for an app" do
      stub_api_request(:post, "/apps/myapp/server/maintenance").with(:body => "maintenance_mode=0")
      @client.maintenance('myapp', :off)
    end
  end

  describe "config vars" do
    it "config_vars(app_name) -> json hash of config vars for the app" do
      stub_api_request(:get, "/apps/myapp/config_vars").to_return(:body => '{"A":"one", "B":"two"}')
      @client.config_vars('myapp').should == { 'A' => 'one', 'B' => 'two'}
    end

    it "add_config_vars(app_name, vars)" do
      stub_api_request(:put, "/apps/myapp/config_vars").with(:body => '{"x":"y"}')
      @client.add_config_vars('myapp', {:x => 'y'})
    end

    it "remove_config_var(app_name, key)" do
      stub_api_request(:delete, "/apps/myapp/config_vars/mykey")
      @client.remove_config_var('myapp', 'mykey')
    end

    it "clear_config_vars(app_name) -> resets all config vars for this app" do
      stub_api_request(:delete, "/apps/myapp/config_vars")
      @client.clear_config_vars('myapp')
    end
  end

  describe "addons" do
    it "addons -> array with addons available for installation" do
      stub_api_request(:get, "/addons").to_return(:body => '[{"name":"addon1"}, {"name":"addon2"}]')
      @client.addons.should == [{'name' => 'addon1'}, {'name' => 'addon2'}]
    end

    it "installed_addons(app_name) -> array of installed addons" do
      stub_api_request(:get, "/apps/myapp/addons").to_return(:body => '[{"name":"addon1"}]')
      @client.installed_addons('myapp').should == [{'name' => 'addon1'}]
    end

    it "install_addon(app_name, addon_name)" do
      stub_api_request(:post, "/apps/myapp/addons/addon1")
      @client.install_addon('myapp', 'addon1')
    end

    it "uninstall_addon(app_name, addon_name)" do
      stub_api_request(:delete, "/apps/myapp/addons/addon1")
      @client.uninstall_addon('myapp', 'addon1')
    end
  end

  describe "internal" do
    before do
      @client = Heroku::Client.new(nil, nil)
    end

    it "creates a RestClient resource for making calls" do
      @client.stub!(:host).and_return('heroku.com')
      @client.stub!(:user).and_return('joe@example.com')
      @client.stub!(:password).and_return('secret')

      res = @client.resource('/xyz')

      res.url.should == 'https://api.heroku.com/xyz'
      res.user.should == 'joe@example.com'
      res.password.should == 'secret'
    end

    it "runs a callback when the API sets a warning header" do
      response = mock('rest client response', :headers => { :x_heroku_warning => 'Warning' })
      @client.should_receive(:resource).with('test').and_return(@resource)
      @resource.should_receive(:get).and_return(response)
      @client.on_warning { |msg| @callback = msg }
      @client.get('test')
      @callback.should == 'Warning'
    end

    it "doesn't run the callback twice for the same warning" do
      response = mock('rest client response', :headers => { :x_heroku_warning => 'Warning' })
      @client.stub!(:resource).and_return(@resource)
      @resource.stub!(:get).and_return(response)
      @client.on_warning { |msg| @callback_called ||= 0; @callback_called += 1 }
      @client.get('test1')
      @client.get('test2')
      @callback_called.should == 1
    end
  end
end
