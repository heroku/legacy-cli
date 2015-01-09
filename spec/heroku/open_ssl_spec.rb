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
end