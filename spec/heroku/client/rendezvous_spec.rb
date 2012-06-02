# -*- coding: utf-8 -*-
require "spec_helper"
require "heroku/client/rendezvous"

describe Heroku::Client, "rendezvous" do
  before do
    @rendezvous = Heroku::Client::Rendezvous.new({
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
      @rendezvous.send(:fixup, "hello world").should eq "hello world"
    end
    it "default Chinese UTF-8 encoded data" do
      @rendezvous.send(:fixup, "“水／火”系列").should eq "“水／火”系列"
    end
    if RUBY_VERSION >= "1.9"
      it "ISO-8859-1 force-encoded data" do
        @rendezvous.send(:fixup, "Центр".force_encoding("ISO-8859-1")).should eq "Центр".force_encoding("UTF-8")
      end
    end
  end
end
