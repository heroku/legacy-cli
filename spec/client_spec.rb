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
		@client.info('myapp').should == { :blessed => 'true', :'created-at' => '2008-07-08T17:21:50-07:00', :id => '49134', :name => 'testgems', :production => 'true', :'share-public' => 'true', :domain_name => nil, :collaborators => [:jon, :mike] }
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
		@resource.should_receive(:post).with({ 'app[name]' => 'newapp' }, @client.heroku_headers).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<app><name>newapp</name></app>
EOXML
		@client.create("newapp").should == "newapp"
	end

	it "create(:origin => url) -> create an app from a public git repo" do
		@client.should_receive(:resource).with('/apps').and_return(@resource)
		@resource.should_receive(:post).with({ 'app[origin]' => 'git://url' }, @client.heroku_headers).and_return <<EOXML
<?xml version="1.0" encoding="UTF-8"?>
<app><name>newapp</name></app>
EOXML
		@client.create(nil, :origin => 'git://url')
	end

	it "update(name, attributes) -> updates existing apps" do
		@client.should_receive(:resource).with('/apps/myapp').and_return(@resource)
		@resource.should_receive(:put).with({ 'app[mode]' => 'production', 'app[public]' => true }, anything)
		@client.update("myapp", :mode => 'production', :public => true)
	end

	it "destroy(name) -> destroy the named app" do
		@client.should_receive(:resource).with('/apps/destroyme').and_return(@resource)
		@resource.should_receive(:delete)
		@client.destroy("destroyme")
	end

	context "collaborators" do
		before do
			@client = Heroku::Client.new(nil, nil)
			@resource = mock('heroku rest resource')
		end

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

	it "upload_authkey(key) -> send the ssh authkey to authorize git push/pull" do
		@client.should_receive(:resource).with('/user/authkey').and_return(@resource)
		@resource.should_receive(:put).with('my key', anything)
		@client.upload_authkey('my key')
	end
end
