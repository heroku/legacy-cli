require "spec_helper"
require "heroku/auth"
require "heroku/helpers"

module Heroku
  describe Auth do
    include Heroku::Helpers

    before do
      ENV['HEROKU_API_KEY'] = nil

      @cli = Heroku::Auth
      @cli.stub!(:check)
      @cli.stub!(:display)
      @cli.stub!(:running_on_a_mac?).and_return(false)
      @cli.credentials = nil

      FakeFS.activate!

      FakeFS::File.stub!(:stat).and_return(double('stat', :mode => "0600".to_i(8)))
      FakeFS::FileUtils.stub!(:chmod)
      FakeFS::File.stub!(:readlines) do |path|
        File.read(path).split("\n").map {|line| "#{line}\n"}
      end

      FileUtils.mkdir_p(@cli.netrc_path.split("/")[0..-2].join("/"))

      File.open(@cli.netrc_path, "w") do |file|
        file.puts("machine api.heroku.com\n  login user\n  password pass\n")
        file.puts("machine code.heroku.com\n  login user\n  password pass\n")
      end
    end

    after do
      FileUtils.rm_rf(@cli.netrc_path)
      FakeFS.deactivate!
    end

    context "legacy credentials" do

      before do
        FileUtils.rm_rf(@cli.netrc_path)
        FileUtils.mkdir_p(File.dirname(@cli.legacy_credentials_path))
        File.open(@cli.legacy_credentials_path, "w") do |file|
          file.puts "legacy_user\nlegacy_pass"
        end
      end

      it "should translate to netrc and cleanup" do
        # preconditions
        File.exist?(@cli.legacy_credentials_path).should == true
        File.exist?(@cli.netrc_path).should == false

        # transition
        @cli.get_credentials.should == ['legacy_user', 'legacy_pass']

        # postconditions
        File.exist?(@cli.legacy_credentials_path).should == false
        File.exist?(@cli.netrc_path).should == true
        Netrc.read(@cli.netrc_path)["api.#{@cli.host}"].should == ['legacy_user', 'legacy_pass']
      end
    end

    context "API key is set via environment variable" do
      before do
        ENV['HEROKU_API_KEY'] = "secret"
      end

      it "gets credentials from environment variables in preference to credentials file" do
        @cli.read_credentials.should == ['', ENV['HEROKU_API_KEY']]
      end

      it "returns a blank username" do
        @cli.user.should be_empty
      end

      it "returns the api key as the password" do
        @cli.password.should == ENV['HEROKU_API_KEY']
      end

      it "does not overwrite credentials file with environment variable credentials" do
        @cli.should_not_receive(:write_credentials)
        @cli.read_credentials
      end

      context "reauthenticating" do
        before do
          @cli.stub!(:ask_for_credentials).and_return(['new_user', 'new_password'])
          @cli.stub!(:check)
          @cli.should_receive(:check_for_associated_ssh_key)
          @cli.reauthorize
        end
        it "updates saved credentials" do
          Netrc.read(@cli.netrc_path)["api.#{@cli.host}"].should == ['new_user', 'new_password']
        end
        it "returns environment variable credentials" do
          @cli.read_credentials.should == ['', ENV['HEROKU_API_KEY']]
        end
      end

      context "logout" do
        before do
          @cli.logout
        end
        it "should delete saved credentials" do
          File.exists?(@cli.legacy_credentials_path).should be_false
          Netrc.read(@cli.netrc_path)["api.#{@cli.host}"].should be_nil
        end
      end
    end

    describe "#base_host" do
      it "returns the host without the first part" do
        @cli.base_host("http://foo.bar.com").should == "bar.com"
      end

      it "works with localhost" do
        @cli.base_host("http://localhost:3000").should == "localhost"
      end
    end

    it "asks for credentials when the file doesn't exist" do
      @cli.delete_credentials
      @cli.should_receive(:ask_for_credentials).and_return(["u", "p"])
      @cli.should_receive(:check_for_associated_ssh_key)
      @cli.user.should == 'u'
      @cli.password.should == 'p'
    end

    it "writes credentials and uploads authkey when credentials are saved" do
      @cli.stub!(:credentials)
      @cli.stub!(:check)
      @cli.stub!(:ask_for_credentials).and_return("username", "apikey")
      @cli.should_receive(:write_credentials)
      @cli.should_receive(:check_for_associated_ssh_key)
      @cli.ask_for_and_save_credentials
    end

    it "save_credentials deletes the credentials when the upload authkey is unauthorized" do
      @cli.stub!(:write_credentials)
      @cli.stub!(:retry_login?).and_return(false)
      @cli.stub!(:ask_for_credentials).and_return("username", "apikey")
      @cli.stub!(:check) { raise Heroku::API::Errors::Unauthorized.new("Login Failed", Excon::Response.new) }
      @cli.should_receive(:delete_credentials)
      lambda { @cli.ask_for_and_save_credentials }.should raise_error(SystemExit)
    end

    it "asks for login again when not authorized, for three times" do
      @cli.stub!(:read_credentials)
      @cli.stub!(:write_credentials)
      @cli.stub!(:delete_credentials)
      @cli.stub!(:ask_for_credentials).and_return("username", "apikey")
      @cli.stub!(:check) { raise Heroku::API::Errors::Unauthorized.new("Login Failed", Excon::Response.new) }
      @cli.should_receive(:ask_for_credentials).exactly(3).times
      lambda { @cli.ask_for_and_save_credentials }.should raise_error(SystemExit)
    end

    it "deletes the credentials file" do
      FileUtils.mkdir_p(File.dirname(@cli.legacy_credentials_path))
      File.open(@cli.legacy_credentials_path, "w") do |file|
        file.puts "legacy_user\nlegacy_pass"
      end
      FileUtils.should_receive(:rm_f).with(@cli.legacy_credentials_path)
      @cli.delete_credentials
    end

    it "writes the login information to the credentials file for the 'heroku login' command" do
      @cli.stub!(:ask_for_credentials).and_return(['one', 'two'])
      @cli.stub!(:check)
      @cli.should_receive(:check_for_associated_ssh_key)
      @cli.reauthorize
      Netrc.read(@cli.netrc_path)["api.#{@cli.host}"].should == (['one', 'two'])
    end

    it "migrates long api keys to short api keys" do
      @cli.delete_credentials
      api_key = "7e262de8cac430d8a250793ce8d5b334ae56b4ff15767385121145198a2b4d2e195905ef8bf7cfc5"
      @cli.netrc["api.#{@cli.host}"] = ["user", api_key]

      @cli.get_credentials.should == ["user", api_key[0,40]]
      %w{api code}.each do |section|
        Netrc.read(@cli.netrc_path)["#{section}.#{@cli.host}"].should == ["user", api_key[0,40]]
      end
    end

    describe "automatic key uploading" do
      before(:each) do
        FileUtils.mkdir_p("#{@cli.home_directory}/.ssh")
        @cli.stub!(:ask_for_credentials).and_return("username", "apikey")
      end

      describe "an account with existing keys" do
        before :each do
          @api = mock(Object)
          @response = mock(Object)
          @response.should_receive(:body).and_return(['existingkeys'])
          @api.should_receive(:get_keys).and_return(@response)
          @cli.should_receive(:api).and_return(@api)
        end

        it "should not do anything if the account already has keys" do
          @cli.should_not_receive(:associate_key)
          @cli.check_for_associated_ssh_key
        end
      end

      describe "an account with no keys" do
        before :each do
          @api = mock(Object)
          @response = mock(Object)
          @response.should_receive(:body).and_return([])
          @api.should_receive(:get_keys).and_return(@response)
          @cli.should_receive(:api).and_return(@api)
        end

        describe "with zero public keys" do
          it "should ask to generate a key" do
            @cli.should_receive(:ask).and_return("y")
            @cli.should_receive(:generate_ssh_key).with("id_rsa")
            @cli.should_receive(:associate_key).with("#{@cli.home_directory}/.ssh/id_rsa.pub")
            @cli.check_for_associated_ssh_key
          end
        end

        describe "with one public key" do
          before(:each) { FileUtils.touch("#{@cli.home_directory}/.ssh/id_rsa.pub") }
          after(:each)  { FileUtils.rm("#{@cli.home_directory}/.ssh/id_rsa.pub") }

          it "should upload the key" do
            @cli.should_receive(:associate_key).with("#{@cli.home_directory}/.ssh/id_rsa.pub")
            @cli.check_for_associated_ssh_key
          end
        end

        describe "with many public keys" do
          before(:each) do
            FileUtils.touch("#{@cli.home_directory}/.ssh/id_rsa.pub")
            FileUtils.touch("#{@cli.home_directory}/.ssh/id_rsa2.pub")
          end

          after(:each) do
            FileUtils.rm("#{@cli.home_directory}/.ssh/id_rsa.pub")
            FileUtils.rm("#{@cli.home_directory}/.ssh/id_rsa2.pub")
          end

          it "should ask which key to upload" do
            File.open("#{@cli.home_directory}/.ssh/id_rsa.pub", "w") { |f| f.puts }
            @cli.should_receive(:associate_key).with("#{@cli.home_directory}/.ssh/id_rsa2.pub")
            @cli.should_receive(:ask).and_return("2")
            @cli.check_for_associated_ssh_key
          end
        end
      end
    end
  end
end
