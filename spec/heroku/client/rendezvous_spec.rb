# -*- coding: utf-8 -*-
require "spec_helper"
require "heroku/client/rendezvous"
require "support/openssl_mock_helper"

describe Heroku::Client, "rendezvous" do
  before do
    @rendezvous = Heroku::Client::Rendezvous.new({
      :rendezvous_url => "https://heroku.local:1234/secret",
      :output => $stdout
    })
  end
  context "fixup" do
    it "null" do
      expect(@rendezvous.send(:fixup, nil)).to be_nil
    end
    it "an empty string" do
      expect(@rendezvous.send(:fixup, "")).to eq ""
    end
    it "hash" do
      expect(@rendezvous.send(:fixup, { :x => :y })).to eq({ :x => :y })
    end
    it "default English UTF-8 data" do
      expect(@rendezvous.send(:fixup, "heroku")).to eq "heroku"
    end
    it "default Japanese UTF-8 encoded data" do
      expect(@rendezvous.send(:fixup, "愛しています")).to eq "愛しています"
    end
    if RUBY_VERSION >= "1.9"
      it "ISO-8859-1 force-encoded data" do
        expect(@rendezvous.send(:fixup, "Хероку".force_encoding("ISO-8859-1"))).to eq "Хероку".force_encoding("UTF-8")
      end
    end
  end
  context "with mock ssl" do
    before :each do
      mock_openssl
      expect(@ssl_socket_mock).to receive(:puts).with("secret")
      expect(@ssl_socket_mock).to receive(:readline).and_return(nil)
    end
    it "should connect to host:post" do
      expect(TCPSocket).to receive(:open).with("heroku.local", 1234).and_return(@tcp_socket_mock)
      allow(IO).to receive(:select).and_return(nil)
      allow(@ssl_socket_mock).to receive(:write)
      allow(@ssl_socket_mock).to receive(:flush) { raise Timeout::Error }
      expect { @rendezvous.start }.to raise_error(Timeout::Error)
    end
    it "should callback on_connect" do
      @rendezvous.on_connect do 
        raise "on_connect"
      end
      expect(TCPSocket).to receive(:open).and_return(@tcp_socket_mock)
      expect { @rendezvous.start }.to raise_error("on_connect")
    end
    it "should fixup received data" do
      expect(TCPSocket).to receive(:open).and_return(@tcp_socket_mock)
      expect(@ssl_socket_mock).to receive(:readpartial).and_return("The quick brown fox jumps over the lazy dog")
      allow(@rendezvous).to receive(:fixup) { |data| raise "received: #{data}" }
      expect { @rendezvous.start }.to raise_error("received: The quick brown fox jumps over the lazy dog")
    end
  end
end
