# encoding: utf-8
#
require "spec_helper"
require "heroku/helpers/env"

module Heroku::Helpers
  describe Env do
    context "[]" do

      before do
        allow(ENV).to receive(:[]).and_return(nil)
        allow(Heroku::Helpers).to receive(:running_on_windows?).and_return(true)
      end

      after do
        allow(ENV).to receive(:[]).and_call_original
        allow(Heroku::Helpers).to receive(:running_on_windows?).and_call_original
      end

      it "Passes through non ASCII-8BIT strings without re-encoding" do
        allow(ENV).to receive(:[]).with('foo').and_return("foo".encode("ISO-8859-1"))

        actual = Heroku::Helpers::Env['foo']

        expect(actual).to eq("foo")
        expect(actual.encoding).to eq(Encoding::ISO_8859_1)
      end

      it "Passes through nil without failing" do
        allow(ENV).to receive(:[]).with('foo').and_return(nil)
        expect(Heroku::Helpers::Env['foo']).to be_nil
      end

      it "Attempts to convert ASCII_8BIT" do
        bad_encoding = "\u0412".force_encoding("ASCII-8BIT").freeze # verify we work with frozen values
        allow(ENV).to receive(:[]).with('foo').and_return(bad_encoding)

        actual = Heroku::Helpers::Env['foo']

        expect(actual).to eq("\u0412")
        expect(actual.encoding).to eq(Encoding::UTF_8)
      end
    end
  end
end
