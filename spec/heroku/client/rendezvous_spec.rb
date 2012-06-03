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
      @rendezvous.send(:fixup, nil).should be_nil
    end
    it "an empty string" do
      @rendezvous.send(:fixup, "").should eq ""
    end
    it "hash" do
      @rendezvous.send(:fixup, { :x => :y }).should eq({ :x => :y })
    end
    it "default English UTF-8 data" do
      @rendezvous.send(:fixup, "heroku").should eq "heroku"
    end
    it "default Japanese UTF-8 encoded data" do
      @rendezvous.send(:fixup, "愛しています").should eq "愛しています"
    end
    if RUBY_VERSION >= "1.9"
      it "ISO-8859-1 force-encoded data" do
        @rendezvous.send(:fixup, "Хероку".force_encoding("ISO-8859-1")).should eq "Хероку".force_encoding("UTF-8")
      end
    end
  end
  context "with mock ssl" do
    before :each do
      mock_openssl
      @ssl_socket_mock.should_receive(:puts).with("secret")
      @ssl_socket_mock.should_receive(:readline).and_return(nil)
    end
    it "should connect to host:post" do
      TCPSocket.should_receive(:open).with("heroku.local", 1234).and_return(@tcp_socket_mock)
      IO.stub(:select).and_return(nil)
      @ssl_socket_mock.stub(:write)
      @ssl_socket_mock.stub(:flush) { raise Timeout::Error }
      lambda { @rendezvous.start }.should raise_error(Timeout::Error)
    end
    it "should callback on_connect" do
      @rendezvous.on_connect do 
        raise "on_connect"
      end
      TCPSocket.should_receive(:open).and_return(@tcp_socket_mock)
      lambda { @rendezvous.start }.should raise_error("on_connect")
    end
    it "should fixup received data" do
      TCPSocket.should_receive(:open).and_return(@tcp_socket_mock)
      @ssl_socket_mock.should_receive(:readpartial).and_return("The quick brown fox jumps over the lazy dog")
      @rendezvous.stub(:fixup) { |data| raise "received: #{data}" }
      lambda { @rendezvous.start }.should raise_error("received: The quick brown fox jumps over the lazy dog")
    end
  end
end
