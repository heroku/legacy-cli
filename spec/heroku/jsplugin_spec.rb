# encoding: utf-8

require "spec_helper"
require "heroku/jsplugin"

module Heroku
  describe JSPlugin do
    context "shellescape" do
      it "should to_s the arguments" do
        expect(Heroku::JSPlugin.shellescape(3)).to eq("3")
      end

      it "should return single quotes for an empty string" do
        expect(Heroku::JSPlugin.shellescape('')).to eq("''")
      end

      it "escape newlines properly" do
        expect(Heroku::JSPlugin.shellescape("\n")).to eq("'\n'")
      end

      it "escapes bad shell commands" do
        expect(Heroku::JSPlugin.shellescape("`$()|;&><'\"")).to eq("\\`\\$\\(\\)\\|\\;\\&\\>\\<\\'\\\"")
      end

      it "passes options through" do
        expect(Heroku::JSPlugin.shellescape("-f")).to eq("-f")
      end

      it "passes multi byte characters through" do
        expect(Heroku::JSPlugin.shellescape("あい")).to eq("あい")
      end

      it "passes ascci numbers and letters through without escaping" do
        expect(Heroku::JSPlugin.shellescape("Aa0")).to eq("Aa0")
      end

      it "passes multi byte characters through" do
        expect(Heroku::JSPlugin.shellescape("あい")).to eq("あい")
      end

      it "passes multi byte numbers through" do
        expect(Heroku::JSPlugin.shellescape("Ⅲ")).to eq("Ⅲ")
      end

      it "does not fail on things that cannot be converted to utf-8" do
        expected_bad_encoding = "\u0412".force_encoding("ASCII-8BIT")
	expected_bad_encoding.gsub!(/([^A-Za-z0-9_\-.,:\/@\n])/, "\\\\\\1")

        bad_encoding = "\u0412".force_encoding("ASCII-8BIT")
        expect(Heroku::JSPlugin.shellescape(bad_encoding)).to eq(expected_bad_encoding)
      end
    end

    context "shelljoin" do
      it "escapes bad shell commands" do
        expect(Heroku::JSPlugin.shelljoin(["`$()|;", "&><'\""])).to eq("\\`\\$\\(\\)\\|\\; \\&\\>\\<\\'\\\"")
      end
    end
  end
end
