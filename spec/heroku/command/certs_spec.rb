require "spec_helper"
require "heroku/command/certs"

module Heroku::Command
  describe Certs do
    let(:endpoint) {
      { 'cname'          => 'tokyo-1050',
        'ssl_cert' => {
          'ca_signed?'   => false,
          'cert_domains' => [ 'example.org' ],
          'starts_at'    => Time.now.to_s,
          'expires_at'   => (Time.now + 365 * 24 * 3600).to_s,
          'issuer'       => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
          'subject'      => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
        }
      }
    }
    let(:endpoint2) {
      { 'cname'          => 'akita-7777',
        'ssl_cert' => {
          'ca_signed?'   => true,
          'cert_domains' => [ 'heroku.com' ],
          'starts_at'    => Time.now.to_s,
          'expires_at'   => (Time.now + 365 * 24 * 3600).to_s,
          'issuer'       => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
          'subject'      => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
        }
      }
    }

    describe "certs" do
      it "shows a list of certs" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint, endpoint2])
        stderr, stdout = execute("certs")
        stdout.should include "Endpoint", "Common Name(s)", "Expires", "Trusted"
        stdout.should include "tokyo-1050", "example.org", "False"
        stdout.should include "akita-7777", "heroku.com", "True"
      end

      it "warns about no SSL endpoints if the app has no certs" do
        stub_core.ssl_endpoint_list("myapp").returns([])
        stderr, stdout = execute("certs")
        stdout.should include "No SSL endpoints setup."
        stdout.should include "Use 'heroku certs:add <pemfile> <keyfile>' to create a SSL endpoint."
      end
    end

    describe "certs:add" do
      it "adds an endpoint" do
        File.should_receive(:read).with("pem_file").and_return("pem content")
        File.should_receive(:read).with("key_file").and_return("key content")
        stub_core.ssl_endpoint_add('myapp', 'pem content', 'key content').returns(endpoint)

        stderr, stdout = execute("certs:add pem_file key_file")
        stdout.should include "Adding SSL endpoint to myapp... done"
        stdout.should include "myapp now served by tokyo-1050"
        stdout.should include "Certificate details:"
        stdout.should include "subject: /C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org"
      end

      it "shows usage if two arguments are not provided" do
        lambda { execute("certs:add") }.should raise_error(CommandFailed, /Usage:/)
      end
    end

    describe "certs:info" do
      it "shows certificate details" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_info('myapp', 'tokyo-1050').returns(endpoint)

        stderr, stdout = execute("certs:info")
        stdout.should include "Fetching information on SSL endpoint tokyo-1050... done"
        stdout.should include "Certificate details:"
        stdout.should include "subject: /C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org"
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:info")
        stderr.should include "!    No SSL endpoints exist for myapp"
      end
    end

    describe "certs:remove" do
      it "removes an endpoint" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_remove('myapp', 'tokyo-1050').returns(endpoint)

        stderr, stdout = execute("certs:remove")
        stdout.should include "Removing SSL endpoint tokyo-1050 from myapp..."
        stdout.should include "De-provisioned endpoint tokyo-1050."
        stdout.should include "NOTE: Billing is still active. Remove SSL endpoint add-on to stop billing."
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:remove")
        stderr.should include "!    No SSL endpoints exist for myapp"
      end
    end

    describe "certs:update" do
      before do
        File.should_receive(:read).with("pem_file").and_return("pem content")
        File.should_receive(:read).with("key_file").and_return("key content")
      end

      it "updates an endpoint" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_update('myapp', 'tokyo-1050', 'pem content', 'key content').returns(endpoint)

        stderr, stdout = execute("certs:update pem_file key_file")
        stdout.should include "Updating SSL endpoint tokyo-1050 for myapp... done"
        stdout.should include "Updated certificate details:"
        stdout.should include "subject: /C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org"
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:update pem_file key_file")
        stderr.should include "!    No SSL endpoints exist for myapp"
      end
    end

    describe "certs:rollback" do
      it "performs a rollback on an endpoint" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_rollback('myapp', 'tokyo-1050').returns(endpoint)

        stderr, stdout = execute("certs:rollback")
        stdout.should include "Rolling back SSL endpoint tokyo-1050 on myapp... done"
        stdout.should include "New active certificate details:"
        stdout.should include "subject: /C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org"
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:rollback")
        stderr.should include "!    No SSL endpoints exist for myapp"
      end
    end
  end
end
