require File.dirname(__FILE__) + '/base'

describe Heroku::Client do
	before do
		@client = Heroku::Client.new(nil, nil)
		@resource = mock('heroku rest resource')
	end

	it "list -> get a list of this user's apps" do
		@client.should_receive(:resource).with('/apps').and_return(@resource)
		@resource.should_receive(:get).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<apps type="array">
	<app><name>myapp1</name></app>
	<app><name>myapp2</name></app>
</apps>
EOXML
		@client.list.should == %w(myapp1 myapp2)
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
		@client.info('myapp').should == { :blessed => 'true', :created_at => '2008-07-08T17:21:50-07:00', :id => '49134', :name => 'testgems', :production => 'true', :share_public => 'true', :domain_name => nil, :collaborators => [:jon, :mike] }
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
		@client.should_receive(:resource).with('/apps/myapp/rake').and_return(@resource)
		@resource.should_receive(:post).with('db:migrate', @client.heroku_headers)
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
		@resources['run'].should_receive(:post).with({:command=>"1+1"}, {"X-Heroku-API-Version"=>"1"}).and_return('2')
		@resources['close'].should_receive(:delete)

		@client.console('myapp') do |c|
			c.run("1+1").should == '2'
		end
	end

	it "restart(app_name) -> restarts the app servers" do
		@client.should_receive(:resource).with('/apps/myapp/server').and_return(@resource)
		@resource.should_receive(:delete).with
		@client.restart('myapp')
	end

	it "logs(app_name) -> returns recent output of the app logs" do
		@client.should_receive(:resource).with('/apps/myapp/logs').and_return(@resource)
		@resource.should_receive(:get).and_return('log')
		@client.logs('myapp').should == 'log'
	end

	describe "collaborators" do
		it "list(app_name) -> list app collaborators" do
			@client.should_receive(:resource).with('/apps/myapp/collaborators').and_return(@resource)
			@resource.should_receive(:get).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<collaborators type="array">
	<collaborator><email>joe@example.com</email><access>edit</access></collaborator>
	<collaborator><email>jon@example.com</email><access>view</access></collaborator>
</collaborators>
EOXML
			@client.list_collaborators('myapp').should == [
				{ :email => 'joe@example.com', :access => 'edit' }, 
				{ :email => 'jon@example.com', :access => 'view' }
			]
		end

		it "add_collaborator(app_name, email, access) -> adds collaborator to app" do
			@client.should_receive(:resource).with('/apps/myapp/collaborators').and_return(@resource)
			@resource.should_receive(:post).with({ 'collaborator[email]' => 'joe@example.com', 'collaborator[access]' => 'edit'}, anything)
			@client.add_collaborator('myapp', 'joe@example.com', 'edit')
		end

		it "update_collaborator(app_name, email, access) -> updates existing collaborator record" do
			@client.should_receive(:resource).with('/apps/myapp/collaborators/joe%40example%2Ecom').and_return(@resource)
			@resource.should_receive(:put).with({ 'collaborator[access]' => 'view'}, anything)
			@client.update_collaborator('myapp', 'joe@example.com', 'view')
		end

		it "remove_collaborator(app_name, email, access) -> removes collaborator from app" do
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
			@client.list_domains('myapp').should == ['example1.com', 'example2.com']
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
	end

	describe "internal" do
		it "creates a RestClient resource for making calls" do
			@client.stub!(:host).and_return('heroku.com')
			@client.stub!(:user).and_return('joe@example.com')
			@client.stub!(:password).and_return('secret')

			res = @client.resource('/xyz')

			res.url.should == 'http://heroku.com/xyz'
			res.user.should == 'joe@example.com'
			res.password.should == 'secret'
		end
	end
end
