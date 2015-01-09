require "heroku/open_ssl"

describe Heroku::OpenSSL do
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
      Heroku::OpenSSL.openssl = nil
    end
    
    it "gives good installation advice on a Mac" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        allow(ex).to receive(:running_on_a_mac?).and_return(true)
        allow(ex).to receive(:running_on_windows?).and_return(false)
        expect(ex.installation_hint).to match(/brew install openssl/)
      }
      Heroku::OpenSSL.openssl = nil
    end
    
    it "gives good installation advice on Windows" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        allow(ex).to receive(:running_on_a_mac?).and_return(false)
        allow(ex).to receive(:running_on_windows?).and_return(true)
        expect(ex.installation_hint).to match(/Win32OpenSSL\.html/)
      }
      Heroku::OpenSSL.openssl = nil
    end
    
    it "gives good installation advice on miscellaneous Unixen" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        allow(ex).to receive(:running_on_a_mac?).and_return(false)
        allow(ex).to receive(:running_on_windows?).and_return(false)
        expect(ex.installation_hint).to match(/'openssl' package/)
      }
      Heroku::OpenSSL.openssl = nil
    end
  end
  
  describe :CertificateRequest do
    it "initializes with good defaults" do
      request = Heroku::OpenSSL::CertificateRequest.new
      expect(request).not_to be_nil
      expect(request.key_size).to eq(2048)
      expect(request.self_signed).to be false
    end
    
    it "creates a key and CSR when self_signed is off" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          request = Heroku::OpenSSL::CertificateRequest.new
          request.domain = 'example.com'
          request.subject = '/CN=example.com'
          
          # Would like to do this, but the current version of rspec doesn't support it
          # expect { result = request.generate }.to output.to_stdout_from_any_process
          result = request.generate
          expect(result).not_to be_nil
          expect(result.key_file).to eq('example.com.key')
          expect(result.csr_file).to eq('example.com.csr')
          expect(result.crt_file).to be_nil
      
          expect(File.read(result.key_file)).to start_with("-----BEGIN RSA PRIVATE KEY-----\n")
          expect(File.read(result.csr_file)).to start_with("-----BEGIN CERTIFICATE REQUEST-----\n")
        end
      end
    end
    
    it "creates a key and certificate when self_signed is on" do
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          request = Heroku::OpenSSL::CertificateRequest.new
          request.domain = 'example.com'
          request.subject = '/CN=example.com'
          request.self_signed = true
      
          # Would like to do this, but the current version of rspec doesn't support it
          # expect { result = request.generate }.to output.to_stdout_from_any_process
          result = request.generate
          expect(result).not_to be_nil
          expect(result.key_file).to eq('example.com.key')
          expect(result.csr_file).to be_nil
          expect(result.crt_file).to eq('example.com.crt')
      
          expect(File.read(result.key_file)).to start_with("-----BEGIN RSA PRIVATE KEY-----\n")
          expect(File.read(result.crt_file)).to start_with("-----BEGIN CERTIFICATE-----\n")
        end
      end
    end
    
    it "uses key_size to control the key's size" do
      skip "Can't be tested without an rspec supporting to_stdout_from_any_process" unless RSpec::Matchers::BuiltIn::Output.method_defined? :to_stdout_from_any_process
      
      Dir.mktmpdir do |dir|
        Dir.chdir(dir) do
          request = Heroku::OpenSSL::CertificateRequest.new
          request.domain = 'example.com'
          request.subject = '/CN=example.com'
          request.key_size = 4096
      
          expect { result = request.generate }.to output(/Generating a 4096 bit RSA private key/).to_stdout_from_any_process
        end
      end
    end
  end
end