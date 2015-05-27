require "spec_helper"
require "heroku/command/domains"

module Heroku::Command
  describe Domains do

    before(:all) do
      api.post_app("name" => "example", "stack" => "cedar")
      api.post_addon("example", "pgbackups:auto-month")
    end

    after(:all) do
      api.delete_app("example")
    end

    before(:each) do
      stub_core
    end

    # TODO: rename after 3.domain-cname is merged
    def stub_get_domains_v3_domain_cname(*custom_hostnames)
      Excon.stub(
        :headers => { "Accept" => "application/vnd.heroku+json; version=3.domain-cname" },
        :method => :get,
        :path => '/apps/example/domains') do
        {
          :body => (
          [
            {
              'kind' => 'default',
              'hostname' => 'example.herokuapp.com',
              'cname' => nil
            }
          ] + custom_hostnames.map { |hostname|
            { 'kind' => 'custom',
              'hostname' => hostname,
              'cname' => 'example.herokudns.com'
            }
          }
          ).to_json,
        }
      end
    end

    # TODO: rename after 3.domain-cname is merged
    def stub_post_domains_v3_domain_cname(custom_hostname)
      Excon.stub(
        :headers => {
          "Accept" => "application/vnd.heroku+json; version=3.domain-cname",
          "Content-Type" => "application/json"
        },
        :method => :post,
        :path => '/apps/example/domains') do
        {
          :status => 201,
          :body => {
            'kind' => 'custom',
            'hostname' => custom_hostname,
            'cname' => 'example.herokudns.com'
          }.to_json,
        }
      end
    end

    context("index") do

      it "lists message with no custom domains" do
        stub_get_domains_v3_domain_cname()
        stderr, stdout = execute("domains")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== Development Domain
example.herokuapp.com

example has no custom domain names.
STDOUT
      end

      it "lists domains when some exist" do
        stub_get_domains_v3_domain_cname('example1.com', 'example2.com')
        stderr, stdout = execute("domains")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== Development Domain
example.herokuapp.com

=== Custom Domains
Domain Name   CNAME Target
------------  ---------------------
example1.com  example.herokudns.com
example2.com  example.herokudns.com
STDOUT
      end

    end

    it "adds domain names" do
      stub_post_domains_v3_domain_cname('example.com')
      stderr, stdout = execute("domains:add example.com")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Adding example.com to example... done
 !    Configure your application's DNS to point to example.herokudns.com
 !    For help, see https://devcenter.heroku.com/articles/custom-domains
STDOUT
    end

    it "shows usage if no domain specified for add" do
      stderr, stdout = execute("domains:add")
      expect(stderr).to eq <<-STDERR
 !    Usage: heroku domains:add DOMAIN
 !    Must specify DOMAIN to add.
      STDERR
    end

    it "removes domain names" do
      api.post_domain("example", "example.com")
      stderr, stdout = execute("domains:remove example.com")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Removing example.com from example... done
STDOUT
    end

    it "shows usage if no domain specified for remove" do
      stderr, stdout = execute("domains:remove")
      expect(stderr).to eq <<-STDERR
 !    Usage: heroku domains:remove DOMAIN
 !    Must specify DOMAIN to remove.
      STDERR
    end

    it "removes all domain names" do
      stub_core.remove_domains("example")
      stderr, stdout = execute("domains:clear")
      expect(stderr).to eq("")
      expect(stdout).to eq <<-STDOUT
Removing all domain names from example... done
STDOUT
    end
  end
end
