require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Auth do
    before do
      @cli = prepare_command(Auth)
      @sandbox = "#{Dir.tmpdir}/cli_spec_#{Process.pid}"
      FileUtils.mkdir_p(@sandbox)
      @credentials_file = "#{@sandbox}/credentials"
      File.open(@credentials_file, "w") { |f| f.write "user\npass\n" }
      @cli.stub!(:credentials_file).and_return(@credentials_file)
      @cli.stub!(:running_on_a_mac?).and_return(false)
    end

    after do
      FileUtils.rm_rf(@sandbox)
    end

    it "reads credentials from the credentials file" do
      @cli.read_credentials.should == %w(user pass)
    end

    it "takes the user from the first line and the password from the second line" do
      @cli.user.should == 'user'
      @cli.password.should == 'pass'
    end

    it "asks for credentials when the file doesn't exist" do
      FileUtils.rm_rf(@sandbox)
      @cli.stub!(:check)
      @cli.stub!(:ask_for_credentials).and_return(["u", "p"])
      @cli.should_receive(:check_for_associated_ssh_key)
      @cli.get_credentials.should == [ 'u', 'p' ]
    end

    it "writes the credentials to a file" do
      @cli.stub!(:credentials).and_return(['one', 'two'])
      @cli.should_receive(:set_credentials_permissions)
      @cli.write_credentials
      File.read(@credentials_file).should == "one\ntwo\n"
    end

    it "sets ~/.heroku/credentials to be readable only by the user" do
      unless RUBY_PLATFORM =~ /mswin32|mingw32/
        sandbox = "#{Dir.tmpdir}/cli_spec_#{Process.pid}"
        FileUtils.rm_rf(sandbox)
        FileUtils.mkdir_p(sandbox)
        fname = "#{sandbox}/file"
        system "touch #{fname}"
        @cli.stub!(:credentials_file).and_return(fname)
        @cli.set_credentials_permissions
        File.stat(sandbox).mode.should == 040700
        File.stat(fname).mode.should == 0100600
      end
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
      @cli.stub!(:check) { raise RestClient::Unauthorized }
      @cli.should_receive(:delete_credentials)
      lambda { @cli.ask_for_and_save_credentials }.should raise_error(SystemExit)
    end

    it "asks for login again when not authorized, for three times" do
      @cli.stub!(:read_credentials)
      @cli.stub!(:write_credentials)
      @cli.stub!(:delete_credentials)
      @cli.stub!(:check_for_associated_ssh_key)
      @cli.stub!(:ask_for_credentials).and_return("username", "apikey")
      @cli.stub!(:check) { raise RestClient::Unauthorized }
      @cli.should_receive(:ask_for_credentials).exactly(3).times
      lambda { @cli.ask_for_and_save_credentials }.should raise_error(SystemExit)
    end

    it "deletes the credentials file" do
      FileUtils.should_receive(:rm_f).with(@cli.credentials_file)
      @cli.delete_credentials
    end

    it "writes the login information to the credentials file for the 'heroku login' command" do
      @cli.stub!(:ask_for_credentials).and_return(['one', 'two'])
      @cli.stub!(:check)
      @cli.stub!(:check_for_associated_ssh_key)
      @cli.reauthorize
      File.read(@credentials_file).should == "one\ntwo\n"
    end

    describe "automatic key uploading" do
      before(:each) do
        FakeFS.activate!
        FileUtils.mkdir_p("~/.ssh")
        FileUtils.mkdir_p("~/.heroku")
        FileUtils.touch("~/.heroku/credentials")
        @cli.stub!(:ask_for_credentials).and_return("username", "apikey")
      end

      after(:each) do
        FakeFS.deactivate!
      end

      describe "an account with existing keys" do
        before :each do
          @client = mock(Object)
          @client.should_receive(:keys).and_return(["existingkey"])
          @cli.should_receive(:client).and_return(@client)
        end

        it "should not do anything if the account already has keys" do
          @cli.should_not_receive(:associate_key)
          @cli.check_for_associated_ssh_key
        end
      end

      describe "an account with no keys" do
        before :each do
          @client = mock(Object)
          @client.should_receive(:keys).and_return([])
          @cli.should_receive(:client).and_return(@client)
        end

        describe "with zero public keys" do
          it "should ask to generate a key" do
            @cli.should_receive(:generate_ssh_key).with("id_rsa")
            @cli.should_receive(:associate_key).with(File.expand_path("~/.ssh/id_rsa.pub"))
            @cli.check_for_associated_ssh_key
          end
        end

        describe "with one public key" do
          before(:each) { FileUtils.touch("~/.ssh/id_rsa.pub") }
          after(:each)  { FileUtils.rm("~/.ssh/id_rsa.pub") }

          it "should prompt to upload the key" do
            @cli.should_receive(:associate_key).with(File.expand_path("~/.ssh/id_rsa.pub"))
            @cli.should_receive(:ask).and_return("y")
            @cli.check_for_associated_ssh_key
          end
        end

        describe "with many public keys" do
          before(:each) do
            FileUtils.touch("~/.ssh/id_rsa.pub")
            FileUtils.touch("~/.ssh/id_rsa2.pub")
          end

          after(:each) do
            FileUtils.rm("~/.ssh/id_rsa.pub")
            FileUtils.rm("~/.ssh/id_rsa2.pub")
          end

          it "should ask which key to upload" do
            @cli.should_receive(:associate_key).with(File.expand_path("~/.ssh/id_rsa2.pub"))
            @cli.should_receive(:ask).and_return("2")
            @cli.check_for_associated_ssh_key
          end
        end
      end
    end
  end
end
