require "spec_helper"
require "heroku/command/certs"

module Heroku::Command
  describe Certs do
    let(:certificate_details) {
      <<-CERTIFICATE_DETAILS.chomp
Common Name(s): example.org
Expires At:     2013-08-01 21:34 UTC
Issuer:         /C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org
Starts At:      2012-08-01 21:34 UTC
Subject:        /C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org
SSL certificate is self signed.
      CERTIFICATE_DETAILS
    }

    let(:endpoint) {
      { 'cname'          => 'tokyo-1050.herokussl.com',
        'ssl_cert' => {
          'ca_signed?'   => false,
          'cert_domains' => [ 'example.org' ],
          'starts_at'    => "2012-08-01 21:34:23 UTC",
          'expires_at'   => "2013-08-01 21:34:23 UTC",
          'issuer'       => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
          'subject'      => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
        }
      }
    }
    let(:endpoint2) {
      { 'cname'          => 'akita-7777.herokussl.com',
        'ssl_cert' => {
          'ca_signed?'   => true,
          'cert_domains' => [ 'heroku.com' ],
          'starts_at'    => "2012-08-01 21:34:23 UTC",
          'expires_at'   => "2013-08-01 21:34:23 UTC",
          'issuer'       => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
          'subject'      => '/C=US/ST=California/L=San Francisco/O=Heroku by Salesforce/CN=secure.example.org',
        }
      }
    }

    describe "certs" do
      it "shows a list of certs" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint, endpoint2])
        stderr, stdout = execute("certs")
        stdout.should == <<-STDOUT
Endpoint                  Common Name(s)  Expires               Trusted
------------------------  --------------  --------------------  -------
tokyo-1050.herokussl.com  example.org     2013-08-01 21:34 UTC  False
akita-7777.herokussl.com  heroku.com      2013-08-01 21:34 UTC  True
STDOUT
      end

      it "warns about no SSL Endpoints if the app has no certs" do
        stub_core.ssl_endpoint_list("myapp").returns([])
        stderr, stdout = execute("certs")
        stdout.should == <<-STDOUT
myapp has no SSL Endpoints.
Use `heroku certs:add PEM KEY` to add one.
        STDOUT
      end
    end

    describe "certs:add" do
      it "adds an endpoint" do
        File.should_receive(:read).with("pem_file").and_return("pem content")
        File.should_receive(:read).with("key_file").and_return("key content")
        stub_core.ssl_endpoint_add('myapp', 'pem content', 'key content').returns(endpoint)

        stderr, stdout = execute("certs:add pem_file key_file")
        stdout.should == <<-STDOUT
Adding SSL Endpoint to myapp... done
myapp now served by tokyo-1050.herokussl.com
Certificate details:
#{certificate_details}
        STDOUT
      end

      it "shows usage if two arguments are not provided" do
        lambda { execute("certs:add") }.should raise_error(CommandFailed, /Usage:/)
      end
    end

    describe "certs:info" do
      it "shows certificate details" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_info('myapp', 'tokyo-1050.herokussl.com').returns(endpoint)

        stderr, stdout = execute("certs:info")
        stdout.should == <<-STDOUT
Fetching SSL Endpoint tokyo-1050.herokussl.com info for myapp... done
Certificate details:
#{certificate_details}
        STDOUT
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:info")
        stderr.should == <<-STDERR
 !    myapp has no SSL Endpoints.
        STDERR
      end
    end

    describe "certs:remove" do
      it "removes an endpoint" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_remove('myapp', 'tokyo-1050.herokussl.com').returns(endpoint)

        stderr, stdout = execute("certs:remove")
        stdout.should include "Removing SSL Endpoint tokyo-1050.herokussl.com from myapp..."
        stdout.should include "NOTE: Billing is still active. Remove SSL Endpoint add-on to stop billing."
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:remove")
        stderr.should == <<-STDERR
 !    myapp has no SSL Endpoints.
        STDERR
      end
    end

    describe "certs:update" do
      before do
        File.should_receive(:read).with("pem_file").and_return("pem content")
        File.should_receive(:read).with("key_file").and_return("key content")
      end

      it "updates an endpoint" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_update('myapp', 'tokyo-1050.herokussl.com', 'pem content', 'key content').returns(endpoint)

        stderr, stdout = execute("certs:update pem_file key_file")
        stdout.should == <<-STDOUT
Updating SSL Endpoint tokyo-1050.herokussl.com for myapp... done
Updated certificate details:
#{certificate_details}
        STDOUT
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:update pem_file key_file")
        stderr.should == <<-STDERR
 !    myapp has no SSL Endpoints.
        STDERR
      end
    end

    describe "certs:rollback" do
      it "performs a rollback on an endpoint" do
        stub_core.ssl_endpoint_list("myapp").returns([endpoint])
        stub_core.ssl_endpoint_rollback('myapp', 'tokyo-1050.herokussl.com').returns(endpoint)

        stderr, stdout = execute("certs:rollback")
        stdout.should == <<-STDOUT
Rolling back SSL Endpoint tokyo-1050.herokussl.com for myapp... done
New active certificate details:
#{certificate_details}
        STDOUT
      end

      it "shows an error if an app has no endpoints" do
        stub_core.ssl_endpoint_list("myapp").returns([])

        stderr, stdout = execute("certs:rollback")
        stderr.should == <<-STDERR
 !    myapp has no SSL Endpoints.
        STDERR
      end
    end
  end
end
