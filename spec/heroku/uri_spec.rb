# encoding: utf-8

require "spec_helper"

describe URI do
  context "parse" do
    it "should be monkeypatched to allow underscores in hosts" do
      URI.parse("https://foo_bar.com")
    end
  end
end
