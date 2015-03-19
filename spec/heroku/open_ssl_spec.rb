require "heroku/open_ssl"

describe Heroku::OpenSSL do
  # This undoes any temporary changes to the property, and also
  # resets the flag indicating the path has already been checked.
  before(:all) do
    Heroku::OpenSSL.openssl = nil
  end
  after(:each) do
    Heroku::OpenSSL.openssl = nil
  end

  describe :openssl do
    it "returns 'openssl' when nothing else is set" do
      expect(Heroku::OpenSSL.openssl).to eq("openssl")
    end

    it "returns the environment's 'OPENSSL' variable when it's set" do
      ENV['OPENSSL'] = '/usr/bin/openssl'
      expect(Heroku::OpenSSL.openssl).to eq('/usr/bin/openssl')
      ENV['OPENSSL'] = nil
    end

    it "can be set with openssl=" do
      Heroku::OpenSSL.openssl = '/usr/local/bin/openssl'
      expect(Heroku::OpenSSL.openssl).to eq('/usr/local/bin/openssl')
      Heroku::OpenSSL.openssl = nil
    end

    it "runs openssl(1) when passed arguments" do
      expect(Heroku::OpenSSL).to receive(:system).with("openssl", "version").and_return(true)
      expect(Heroku::OpenSSL.openssl("version")).to be true
    end
  end

  describe :ensure_openssl_installed! do
    it "calls openssl(1) to ensure it's available" do
      expect(Heroku::OpenSSL).to receive(:openssl).with("version").and_return(true)
      Heroku::OpenSSL.ensure_openssl_installed!
    end

    it "detects openssl(1) is available when it is available" do
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.not_to raise_error
    end

    it "detects openssl(1) is absent when it isn't available" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError)
    end

    it "gives good installation advice on a Mac" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        allow(ex).to receive(:running_on_a_mac?).and_return(true)
        allow(ex).to receive(:running_on_windows?).and_return(false)
        expect(ex.installation_hint).to match(/brew install openssl/)
      }
    end

    it "gives good installation advice on Windows" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        allow(ex).to receive(:running_on_a_mac?).and_return(false)
        allow(ex).to receive(:running_on_windows?).and_return(true)
        expect(ex.installation_hint).to match(/Win32OpenSSL\.html/)
      }
    end

    it "gives good installation advice on miscellaneous Unixen" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        allow(ex).to receive(:running_on_a_mac?).and_return(false)
        allow(ex).to receive(:running_on_windows?).and_return(false)
        expect(ex.installation_hint).to match(/'openssl' package/)
      }
    end
  end

  describe :certificate_request do
    it "initializes with good defaults" do
      request = Heroku::OpenSSL::CertificateRequest.new
      expect(request).not_to be_nil
      expect(request.key_size).to eq(2048)
      expect(request.self_signed).to be false
    end

    context "generating with self_signed off" do
      before(:all) do
        @prev_dir = Dir.getwd
        @dir = Dir.mktmpdir
        Dir.chdir @dir

        request = Heroku::OpenSSL::CertificateRequest.new
        request.domain = 'example.com'
        request.subject = '/CN=example.com'

        # Would like to do this, but the current version of rspec doesn't support it
        # expect { result = request.generate }.to output.to_stdout_from_any_process
        @result = request.generate
      end

      it "should create Result object" do
        expect(@result).to be_kind_of Heroku::OpenSSL::CertificateRequest::Result
      end

      it "should have a key filename" do
        expect(@result.key_file).to eq('example.com.key')
      end

      it "should have a CSR filename" do
        expect(@result.csr_file).to eq('example.com.csr')
      end

      it "should not have a certificate filename" do
        expect(@result.crt_file).to be_nil
      end

      it "should produce a PEM key file" do
        expect(File.read(@result.key_file)).to match(/\A-----BEGIN (RSA )?PRIVATE KEY-----\n/)
      end

      it "should produce a PEM certificate file" do
        expect(File.read(@result.csr_file)).to start_with("-----BEGIN CERTIFICATE REQUEST-----\n")
      end

      after(:all) do
        Dir.chdir @prev_dir
        FileUtils.remove_entry_secure @dir
      end
    end

    context "generating with self_signed on" do
      before(:all) do
        @prev_dir = Dir.getwd
        @dir = Dir.mktmpdir
        Dir.chdir @dir

        request = Heroku::OpenSSL::CertificateRequest.new
        request.domain = 'example.com'
        request.subject = '/CN=example.com'
        request.self_signed = true

        # Would like to do this, but the current version of rspec doesn't support it
        # expect { result = request.generate }.to output.to_stdout_from_any_process
        @result = request.generate
      end

      it "should create Result object" do
        expect(@result).to be_kind_of Heroku::OpenSSL::CertificateRequest::Result
      end

      it "should have a key filename" do
        expect(@result.key_file).to eq('example.com.key')
      end

      it "should not have a CSR filename" do
        expect(@result.csr_file).to be_nil
      end

      it "should have a certificate filename" do
        expect(@result.crt_file).to eq('example.com.crt')
      end

      it "should produce a PEM key file" do
        expect(File.read(@result.key_file)).to match(/\A-----BEGIN (RSA )?PRIVATE KEY-----\n/)
      end

      it "should produce a PEM certificate file" do
        expect(File.read(@result.crt_file)).to start_with("-----BEGIN CERTIFICATE-----\n")
      end

      after(:all) do
        Dir.chdir @prev_dir
        FileUtils.remove_entry_secure @dir
      end
    end

    it "raises installation error when openssl(1) isn't installed" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'

      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          request = Heroku::OpenSSL::CertificateRequest.new
          request.domain = 'example.com'
          request.subject = '/CN=example.com'

          expect { request.generate }.to raise_error(Heroku::OpenSSL::NotInstalledError)
        end
      end

      Heroku::OpenSSL.openssl = nil
    end
  end
end
