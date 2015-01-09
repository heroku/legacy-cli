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
        expect(ex).to receive(:running_on_a_mac?).and_return(true)
        expect(ex.installation_hint).to match(/brew install openssl/)
      }
      Heroku::OpenSSL.openssl = nil
    end
    
    it "gives good installation advice on Windows" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        expect(ex).to receive(:running_on_a_mac?).and_return(false)
        expect(ex).to receive(:running_on_windows?).and_return(true)
        expect(ex.installation_hint).to match(/Win32OpenSSL\.html/)
      }
      Heroku::OpenSSL.openssl = nil
    end
    
    it "gives good installation advice on miscellaneous Unixen" do
      Heroku::OpenSSL.openssl = 'openssl-THIS-FILE-SHOULD-NOT-EXIST'
      expect { Heroku::OpenSSL.ensure_openssl_installed! }.to raise_error(Heroku::OpenSSL::NotInstalledError) { |ex|
        expect(ex).to receive(:running_on_a_mac?).and_return(false)
        expect(ex).to receive(:running_on_windows?).and_return(false)
        expect(ex.installation_hint).to match(/'openssl' package/)
      }
      Heroku::OpenSSL.openssl = nil
    end
  end
end