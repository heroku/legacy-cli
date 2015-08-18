require "spec_helper"
require "heroku/command/apps"

module Heroku::Command
  describe Apps do

    before(:each) do
      stub_core
      stub_get_space_v3_dogwood
      stub_organizations
      ENV.delete('HEROKU_ORGANIZATION')
    end

    context("info") do

      before(:each) do
        api.post_app("name" => "example", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "displays implicit app info" do
        stderr, stdout = execute("apps:info")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== example
Git URL:       https://git.heroku.com/example.git
Owner Email:   email@example.com
Stack:         cedar-10
Web URL:       http://example.herokuapp.com/
STDOUT
      end

      it "gets explicit app from --app" do
        stderr, stdout = execute("apps:info --app example")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== example
Git URL:       https://git.heroku.com/example.git
Owner Email:   email@example.com
Stack:         cedar-10
Web URL:       http://example.herokuapp.com/
STDOUT
      end

      it "shows shell app info when --shell option is used" do
        stderr, stdout = execute("apps:info --shell")
        expect(stderr).to eq("")
        expect(stdout).to match Regexp.new(<<-STDOUT)
create_status=complete
created_at=\\d{4}/\\d{2}/\\d{2} \\d{2}:\\d{2}:\\d{2} [+-]\\d{4}
dynos=0
git_url=https://git.heroku.com/example.git
id=\\d{1,5}
name=example
owner_email=email@example.com
repo_migrate_status=complete
repo_size=
requested_stack=
slug_size=
stack=cedar
web_url=http://example.herokuapp.com/
workers=0
STDOUT
      end

    end

    context("create") do

      it "without a name" do
        name = nil
        with_blank_git_repository do
          stderr, stdout = execute("apps:create")
          name = api.get_apps.body.first["name"]
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating #{name}... done, stack is bamboo-mri-1.9.2
http://#{name}.herokuapp.com/ | https://git.heroku.com/#{name}.git
Git remote heroku added
STDOUT
        end
        api.delete_app(name)
      end

      it "with a name" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create example")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating example... done, stack is bamboo-mri-1.9.2
http://example.herokuapp.com/ | https://git.heroku.com/example.git
Git remote heroku added
STDOUT
        end
        api.delete_app("example")
      end

      it "with -a name" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create -a example")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating example... done, stack is bamboo-mri-1.9.2
http://example.herokuapp.com/ | https://git.heroku.com/example.git
Git remote heroku added
STDOUT
        end
        api.delete_app("example")
      end

      it "with --no-remote" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create example --no-remote")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating example... done, stack is bamboo-mri-1.9.2
http://example.herokuapp.com/ | https://git.heroku.com/example.git
STDOUT
        end
        api.delete_app("example")
      end

      it "with addons" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create addonapp --addon pgbackups:auto-month")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating addonapp... done, stack is bamboo-mri-1.9.2
Adding pgbackups:auto-month to addonapp... done
http://addonapp.herokuapp.com/ | https://git.heroku.com/addonapp.git
Git remote heroku added
STDOUT
        end
        api.delete_app("addonapp")
      end

      it "with a buildpack" do
        Excon.stub({:method => :put, :path => "/apps/buildpackapp/buildpack-installations"}, {:status => 200})
        with_blank_git_repository do
          stderr, stdout = execute("apps:create buildpackapp --buildpack http://example.org/buildpack.git")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating buildpackapp... done, stack is bamboo-mri-1.9.2
Buildpack set. Next release on buildpackapp will use http://example.org/buildpack.git.
http://buildpackapp.herokuapp.com/ | https://git.heroku.com/buildpackapp.git
Git remote heroku added
STDOUT
        end
        api.delete_app("buildpackapp")
      end

      it "with an alternate remote name" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create alternate-remote --remote alternate")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating alternate-remote... done, stack is bamboo-mri-1.9.2
http://alternate-remote.herokuapp.com/ | https://git.heroku.com/alternate-remote.git
Git remote alternate added
STDOUT
        end
        api.delete_app("alternate-remote")
      end

      context "with a space" do
        shared_examples "create in a space" do
          Excon.stub(
            :headers => { 'Accept' => 'application/vnd.heroku+json; version=3.dogwood'},
            :method => :post,
            :path => '/organizations/apps') do
            {
              :status => 201,
              :body => {
                :name => 'spaceapp',
                :space => {
                  :name => 'example-space'
                },
                :stack => 'cedar-14',
                :web_url => 'http://spaceapp.herokuapp.com/'
              }.to_json,
            }
          end

          it "creates app in space" do
            with_blank_git_repository do
              stderr, stdout = execute("apps:create spaceapp --space test-space")
              expect(stderr).to eq("")
              expect(stdout).to eq <<-STDOUT
Creating spaceapp in space test-space... done, stack is cedar-14
http://spaceapp.herokuapp.com/ | https://git.heroku.com/spaceapp.git
Git remote heroku added
              STDOUT
            end
          end
        end

        context "with default org" do
          before(:each) do
            ENV['HEROKU_ORGANIZATION'] = 'test-org'
          end

          it_behaves_like "create in a space"
        end

        context "without default org" do
          before(:each) do
            ENV.delete('HEROKU_ORGANIZATION')
          end

          it_behaves_like "create in a space"
        end
      end
    end

    context("index") do

      before(:each) do
        api.post_app("name" => "example", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "succeeds" do
        stub_core.list.returns([["example", "user"]])
        stderr, stdout = execute("apps")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== My Apps
example

STDOUT
      end

    end

    context("index with orgs") do
      context("when you are a member of the org") do
        it "displays a message when the org has no apps" do
          Excon.stub({ :method => :get, :path => '/v1/organization/test-org/app' }, { :status => 200, :body => MultiJson.dump([]) })
          stderr, stdout = execute("apps -o test-org")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
There are no apps in organization test-org.
STDOUT

        end

        context("and the org has apps") do
          before(:each) do
            Excon.stub({ :method => :get, :path => '/v1/organization/test-org/app' },
              {
                :body   => MultiJson.dump([
                  {"name" => "org-app-1", "joined" => true},
                  {"name" => "org-app-2"}
                ]),
                :status => 200
              }
            )
          end

          it "list all in an organization" do
            stderr, stdout = execute("apps -o test-org")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
=== Apps in organization test-org
org-app-1
org-app-2

STDOUT
          end
        end
      end
    end

    context("index with space") do
      shared_examples "index with space" do
        context("and the space has no apps") do
          before(:each) do
            Excon.stub({ :method => :get, :path => '/v1/organization/test-org/app' }) do
              {
                :body   => MultiJson.dump([]),
                :status => 200
              }
            end
          end

          it "displays a message when the space has no apps" do
            stderr, stdout = execute("apps --space test-space")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
There are no apps in space test-space.
STDOUT
          end
        end

        context("and the space has apps") do
          before(:each) do
            Excon.stub({ :method => :get, :path => '/v1/organization/test-org/app' }) do
              {
                :body   => MultiJson.dump([
                    { :name => 'space-app-1', :space => {:id => 'test-space-id', :name => 'test-space'}, :joined => true },
                    { :name => 'space-app-2', :space => {:id => 'test-space-id', :name => 'test-space'}, :joined => false },
                    { :name => 'non-space-app-2', :space => nil, :joined => true }
                  ]),
                :status => 200
              }
            end
          end

          it "lists only apps in spaces by name" do
            stderr, stdout = execute("apps --space test-space")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
=== Apps in space test-space
space-app-1
space-app-2

STDOUT
          end
        end
      end

      context "with default org" do
        before(:each) do
          ENV['HEROKU_ORGANIZATION'] = 'test-org'
        end

        it_behaves_like "index with space"
      end

      context "without default org" do
        before(:each) do
          ENV.delete('HEROKU_ORGANIZATION')
        end

        it_behaves_like "index with space"
      end
    end

    context("index with space and org") do
      before(:each) do
        Excon.stub({ :method => :get, :path => '/v1/organization/test-org/app' }) do
          {
            :body   => MultiJson.dump([]),
            :status => 200
          }
        end
      end

      it "displays error to not specify both" do
        stderr, stdout = execute("apps --space test-space --org test-org")
        expect(stdout).to eq("")
        expect(stderr).to eq <<-STDERR
 !    Specify option for space or org, but not both.
STDERR
      end

      it "does not display error if org specified via env" do
        ENV['HEROKU_ORGANIZATION'] = 'test-org'
        stderr, stdout = execute("apps --space test-space")
        expect(stderr).to eq("")
      end
    end

    context("rename") do

      context("success") do

        before(:each) do
          api.post_app("name" => "example", "stack" => "cedar")
        end

        after(:each) do
          api.delete_app("example2")
        end

        it "renames app" do
          with_blank_git_repository do
            stderr, stdout = execute("apps:rename example2")
            expect(stderr).to eq("")
            expect(stdout).to eq <<-STDOUT
Renaming example to example2... done
http://example2.herokuapp.com/ | https://git.heroku.com/example2.git
Don't forget to update your Git remotes on any local checkouts.
STDOUT
          end
        end

      end

      it "displays an error if no name is specified" do
        stderr, stdout = execute("apps:rename")
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku apps:rename NEWNAME
 !    Must specify NEWNAME to rename.
STDERR
        expect(stdout).to eq("")
      end

    end

    context("destroy") do

      before(:each) do
        api.post_app("name" => "example", "stack" => "cedar")
      end

      it "succeeds with app explicitly specified with --app and user confirmation" do
        stderr, stdout = execute("apps:destroy --confirm example")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Destroying example (including all add-ons)... done
STDOUT
      end

      context("fails") do

        after(:each) do
          api.delete_app("example")
        end

        it "fails with explicit app but no confirmation" do
          stderr, stdout = execute("apps:destroy example")
          expect(stderr).to eq <<-STDERR
 !    Confirmation did not match example. Aborted.
STDERR
          expect(stdout).to eq("
 !    WARNING: Potentially Destructive Action
 !    This command will destroy example (including all add-ons).
 !    To proceed, type \"example\" or re-run this command with --confirm example

> ")

        end

        it "fails without explicit app" do
          stderr, stdout = execute("apps:destroy")
          expect(stderr).to eq <<-STDERR
 !    Usage: heroku apps:destroy --app APP
 !    Must specify APP to destroy.
STDERR
          expect(stdout).to eq("")
        end

      end

    end

    context "Git Integration" do

      it "creates adding heroku to git remote" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create example")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating example... done, stack is bamboo-mri-1.9.2
http://example.herokuapp.com/ | https://git.heroku.com/example.git
Git remote heroku added
STDOUT
          expect(`git remote`.strip).to match(/^heroku$/)
          api.delete_app("example")
        end
      end

      it "creates adding a custom git remote" do
        with_blank_git_repository do
          stderr, stdout = execute("apps:create example --remote myremote")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating example... done, stack is bamboo-mri-1.9.2
http://example.herokuapp.com/ | https://git.heroku.com/example.git
Git remote myremote added
STDOUT
          expect(`git remote`.strip).to match(/^myremote$/)
          api.delete_app("example")
        end
      end

      it "doesn't add a git remote if it already exists" do
        with_blank_git_repository do
          `git remote add heroku /tmp/git_spec_#{Process.pid}`
          stderr, stdout = execute("apps:create example")
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Creating example... done, stack is bamboo-mri-1.9.2
http://example.herokuapp.com/ | https://git.heroku.com/example.git
STDOUT
          api.delete_app("example")
        end
      end

      it "renames updating the corresponding heroku git remote" do
        with_blank_git_repository do
          `git remote add github     git@github.com:test/test.git`
          `git remote add production https://git.heroku.com/example.git`
          `git remote add staging    https://git.heroku.com/example-staging.git`

          api.post_app("name" => "example", "stack" => "cedar")
          stderr, stdout = execute("apps:rename example2")
          api.delete_app("example2")

          remotes = `git remote -v`
          expect(remotes).to eq <<-REMOTES
github\tgit@github.com:test/test.git (fetch)
github\tgit@github.com:test/test.git (push)
production\thttps://git.heroku.com/example2.git (fetch)
production\thttps://git.heroku.com/example2.git (push)
staging\thttps://git.heroku.com/example-staging.git (fetch)
staging\thttps://git.heroku.com/example-staging.git (push)
REMOTES
        end
      end

      it "destroys removing any remotes pointing to the app" do
        with_blank_git_repository do
          `git remote add heroku https://git.heroku.com/example.git`

          api.post_app("name" => "example", "stack" => "cedar")
          stderr, stdout = execute("apps:destroy --confirm example")

          expect(`git remote`.strip).not_to include('heroku')
        end
      end
    end

    def stub_get_space_v3_dogwood
      Excon.stub(
        :headers => { 'Accept' => 'application/vnd.heroku+json; version=3.dogwood' },
        :method => :get,
        :path => '/spaces/test-space') do
        {
          :body => {
            :created_at => '2015-08-12T19:37:02Z',
            :id => '6989c417-304f-4394-b958-f42bc6e1fa4e',
            :name => 'test1',
            :organization => {
              :name => 'test-org'
            },
            :state => 'allocated',
            :updated_at => '2015-08-12T19:48:07Z'
          }.to_json,
        }
      end
    end
  end
end
