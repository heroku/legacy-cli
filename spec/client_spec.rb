require File.dirname(__FILE__) + '/base'

describe Heroku::Client do
	before do
		@client = Heroku::Client.new(nil, nil)
		@resource = mock('heroku rest resource')
		@client.stub!(:extract_warning)
	end

	it "list -> get a list of this user's apps" do
		@client.should_receive(:resource).with('/apps').and_return(@resource)
		@resource.should_receive(:get).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
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
		@client.should_receive(:resource).with('/apps/myapp').and_return(@resource)
		@resource.should_receive(:get).and_return <<EOXML
<?xml version='1.0' encoding='UTF-8'?>
<app>
	<blessed type='boolean'>true</blessed>
	<created-at type='datetime'>2008-07-08T17:21:50-07:00</created-at>
	<id type='integer'>49134</id>
	<name>testgems</name>
	<production type='boolean'>true</production>
	<share-public type='boolean'>true</share-public>
	<domain_name/>
</app>
EOXML
		@client.stub!(:list_collaborators).and_return([:jon, :mike])
		@client.stub!(:installed_addons).and_return([:addon1])
		@client.info('myapp').should == { :blessed => 'true', :created_at => '2008-07-08T17:21:50-07:00', :id => '49134', :name => 'testgems', :production => 'true', :share_public => 'true', :domain_name => nil, :collaborators => [:jon, :mike], :addons => [:addon1] }
	end

	it "create -> create a new blank app" do
		@client.should_receive(:resource).with('/apps').and_return(@resource)
		@resource.should_receive(:post).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<app><name>untitled-123</name></app>
EOXML
		@client.create.should == "untitled-123"
	end

	it "create(name) -> create a new blank app with a specified name" do
		@client.should_receive(:resource).with('/apps').and_return(@resource)
		@resource.should_receive(:post).with({ :app => { :name => 'newapp' } }, @client.heroku_headers).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<app><name>newapp</name></app>
EOXML
		@client.create("newapp").should == "newapp"
	end

	it "update(name, attributes) -> updates existing apps" do
		@client.should_receive(:resource).with('/apps/myapp').and_return(@resource)
		@resource.should_receive(:put).with({ :app => { :mode => 'production', :public => true } }, anything)
		@client.update("myapp", :mode => 'production', :public => true)
	end

	it "destroy(name) -> destroy the named app" do
		@client.should_receive(:resource).with('/apps/destroyme').and_return(@resource)
		@resource.should_receive(:delete)
		@client.destroy("destroyme")
	end

	it "rake(app_name, cmd) -> run a rake command on the app" do
		@client.should_receive(:resource).with('/apps/myapp/services').and_return(@resource)
		@resource.should_receive(:post).with('rake db:migrate', @client.heroku_headers.merge(:content_type => 'text/plain'))
		@client.rake('myapp', 'db:migrate')
	end

	it "console(app_name, cmd) -> run a console command on the app" do
		@client.should_receive(:resource).with('/apps/myapp/console').and_return(@resource)
		@resource.should_receive(:post).with('2+2', @client.heroku_headers)
		@client.console('myapp', '2+2')
	end

	it "console(app_name) { |c| } -> opens a console session, yields one accessor and closes it after the block" do
		@resources = %w( open run close ).inject({}) { |h, r| h[r] = mock("resource for console #{r}"); h }
		@client.should_receive(:resource).with('/apps/myapp/consoles').and_return(@resources['open'])
		@client.should_receive(:resource).with('/apps/myapp/consoles/42/command').and_return(@resources['run'])
		@client.should_receive(:resource).with('/apps/myapp/consoles/42').and_return(@resources['close'])
		@resources['open'].should_receive(:post).and_return(42)
		@resources['run'].should_receive(:post).with("1+1", anything).and_return('2')
		@resources['close'].should_receive(:delete)

		@client.console('myapp') do |c|
			c.run("1+1").should == '=> 2'
		end
	end

	it "restart(app_name) -> restarts the app servers" do
		@client.should_receive(:resource).with('/apps/myapp/server').and_return(@resource)
		@resource.should_receive(:delete).with(anything)
		@client.restart('myapp')
	end

	it "logs(app_name) -> returns recent output of the app logs" do
		@client.should_receive(:resource).with('/apps/myapp/logs').and_return(@resource)
		@resource.should_receive(:get).and_return('log')
		@client.logs('myapp').should == 'log'
	end

	it "cron_logs(app_name) -> returns recent output of the app logs" do
		@client.should_receive(:resource).with('/apps/myapp/cron_logs').and_return(@resource)
		@resource.should_receive(:get).and_return('cron log')
		@client.cron_logs('myapp').should == 'cron log'
	end

	it "set_dynos(app_name, qty) -> scales the app" do
		@client.should_receive(:resource).with('/apps/myapp/dynos').and_return(@resource)
		@resource.should_receive(:put).with({ :dynos => 3 }, anything)
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
			@client.should_receive(:get).with("/apps/myapp/bundles/latest", {:accept=>"application/json"}).and_return("{\"name\":\"bundle1\",\"temporary_url\":\"https:\\/\\/s3.amazonaws.com\\/herokubundles\\/123.tar.gz\"}")
			@client.bundle_url('myapp').should == 'https://s3.amazonaws.com/herokubundles/123.tar.gz'
		end
	end

	describe "collaborators" do
		it "list(app_name) -> list app collaborators" do
			@client.should_receive(:resource).with('/apps/myapp/collaborators').and_return(@resource)
			@resource.should_receive(:get).and_return <<EOXML
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
			@client.should_receive(:resource).with('/apps/myapp/collaborators').and_return(@resource)
			@resource.should_receive(:post).with({ 'collaborator[email]' => 'joe@example.com'}, anything)
			@client.add_collaborator('myapp', 'joe@example.com')
		end

		it "remove_collaborator(app_name, email) -> removes collaborator from app" do
			@client.should_receive(:resource).with('/apps/myapp/collaborators/joe%40example%2Ecom').and_return(@resource)
			@resource.should_receive(:delete)
			@client.remove_collaborator('myapp', 'joe@example.com')
		end
	end

	describe "domain names" do
		it "list(app_name) -> list app domain names" do
			@client.should_receive(:resource).with('/apps/myapp/domains').and_return(@resource)
			@resource.should_receive(:get).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<domain-names type="array">
	<domain-name><domain>example1.com</domain></domain-name>
	<domain-name><domain>example2.com</domain></domain-name>
</domain-names>
EOXML
			@client.list_domains('myapp').should == [{:domain => 'example1.com'}, {:domain => 'example2.com'}]
		end

		it "add_domain(app_name, domain) -> adds domain name to app" do
			@client.should_receive(:resource).with('/apps/myapp/domains').and_return(@resource)
			@resource.should_receive(:post).with('example.com', anything)
			@client.add_domain('myapp', 'example.com')
		end

		it "remove_domain(app_name, domain) -> removes domain name from app" do
			@client.should_receive(:resource).with('/apps/myapp/domains/example.com').and_return(@resource)
			@resource.should_receive(:delete)
			@client.remove_domain('myapp', 'example.com')
		end

		it "remove_domains(app_name) -> removes all domain names from app" do
			@client.should_receive(:resource).with('/apps/myapp/domains').and_return(@resource)
			@resource.should_receive(:delete)
			@client.remove_domains('myapp')
		end

		it "add_ssl(app_name, pem, key) -> adds a ssl cert to the domain" do
			@client.should_receive(:resource).with('/apps/myapp/ssl').and_return(@resource)
			@resource.should_receive(:post).with({ :pem => 'pem', :key => 'key' }, anything).and_return('{}')
			@client.add_ssl('myapp', 'pem', 'key')
		end

		it "remove_ssl(app_name, domain) -> removes the ssl cert for the domain" do
			@client.should_receive(:resource).with('/apps/myapp/domains/example.com/ssl').and_return(@resource)
			@resource.should_receive(:delete)
			@client.remove_ssl('myapp', 'example.com')
		end
	end

	describe "ssh keys" do
		it "fetches a list of the user's current keys" do
			@client.should_receive(:resource).with('/user/keys').and_return(@resource)
			@resource.should_receive(:get).and_return <<EOXML
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
			@client.should_receive(:resource).with('/user/keys').and_return(@resource)
			@client.stub!(:heroku_headers).and_return({})
			@resource.should_receive(:post).with('a key', 'Content-Type' => 'text/ssh-authkey')
			@client.add_key('a key')
		end

		it "remove_key(key) -> remove an ssh key by name (user@box)" do
			@client.should_receive(:resource).with('/user/keys/joe%40workstation').and_return(@resource)
			@resource.should_receive(:delete)
			@client.remove_key('joe@workstation')
		end

		it "remove_all_keys -> removes all ssh keys for the user" do
			@client.should_receive(:resource).with('/user/keys').and_return(@resource)
			@resource.should_receive(:delete)
			@client.remove_all_keys
		end

		it "database_session(app_name) -> creates a taps database session" do
			@client.should_receive(:resource).with('/apps/myapp/database/session').and_return(@resource)
			@resource.should_receive(:post).with('', anything)
			@client.database_session('myapp')
		end

		it "database_reset(app_name) -> reset an app's database" do
			@client.should_receive(:resource).with('/apps/myapp/database/reset').and_return(@resource)
			@resource.should_receive(:post).with('', anything)
			@client.database_reset('myapp')
		end

		it "maintenance(app_name, :on) -> sets maintenance mode for an app" do
			@client.should_receive(:resource).with('/apps/myapp/server/maintenance').and_return(@resource)
			@resource.should_receive(:post).with({:maintenance_mode => '1'}, anything)
			@client.maintenance('myapp', :on)
		end

		it "maintenance(app_name, :off) -> turns off maintenance mode for an app" do
			@client.should_receive(:resource).with('/apps/myapp/server/maintenance').and_return(@resource)
			@resource.should_receive(:post).with({:maintenance_mode => '0'}, anything)
			@client.maintenance('myapp', :off)
		end
	end

	describe "config vars" do
		it "config_vars(app_name) -> json hash of config vars for the app" do
			@client.should_receive(:resource).with('/apps/myapp/config_vars').and_return(@resource)
			@resource.should_receive(:get).and_return '{"A":"one", "B":"two"}'
			@client.config_vars('myapp').should == { 'A' => 'one', 'B' => 'two'}
		end

		it "add_config_vars(app_name, vars)" do
			@client.should_receive(:resource).with('/apps/myapp/config_vars').and_return(@resource)
			@resource.should_receive(:put).with('{"x":"y"}', anything)
			@client.add_config_vars('myapp', {:x => 'y'})
		end

		it "remove_config_var(app_name, key)" do
			@client.should_receive(:resource).with('/apps/myapp/config_vars/mykey').and_return(@resource)
			@resource.should_receive(:delete)
			@client.remove_config_var('myapp', 'mykey')
		end

		it "clear_config_vars(app_name) -> resets all config vars for this app" do
			@client.should_receive(:resource).with('/apps/myapp/config_vars').and_return(@resource)
			@resource.should_receive(:delete)
			@client.clear_config_vars('myapp')
		end
	end

	describe "addons" do
		it "addons -> array with addons available for installation" do
			@client.should_receive(:resource).with('/addons').and_return(@resource)
			@resource.should_receive(:get).and_return '[{"name":"addon1"}, {"name":"addon2"}]'
			@client.addons.should == [{'name' => 'addon1'}, {'name' => 'addon2'}]
		end

		it "installed_addons(app_name) -> array of installed addons" do
			@client.should_receive(:resource).with('/apps/myapp/addons').and_return(@resource)
			@resource.should_receive(:get).and_return '[{"name":"addon1"}]'
			@client.installed_addons('myapp').should == [{'name' => 'addon1'}]
		end

		it "install_addon(app_name, addon_name)" do
			@client.should_receive(:resource).with('/apps/myapp/addons/addon1').and_return(@resource)
			@resource.should_receive(:post)
			@client.install_addon('myapp', 'addon1')
		end

		it "uninstall_addon(app_name, addon_name)" do
			@client.should_receive(:resource).with('/apps/myapp/addons/addon1').and_return(@resource)
			@resource.should_receive(:delete)
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
