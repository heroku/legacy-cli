# encoding: utf-8

require "spec_helper"
require "heroku/jsplugin"

module Heroku
  describe JSPlugin do
    context "app_dir" do
      before do
        allow(Heroku::JSPlugin).to receive(:windows?).and_return(true)
        allow(ENV).to receive(:[]).and_return(nil)
      end

      it "should use LOCALAPPDATA only in windows" do
        allow(ENV).to receive(:[]).with("LOCALAPPDATA").and_return("foo")
        allow(ENV).to receive(:[]).with("XDG_DATA_HOME").and_return("bar")
        expect(Heroku::JSPlugin.app_dir).to eq(File.join("foo", "heroku"))

        allow(Heroku::JSPlugin).to receive(:windows?).and_return(false)
        expect(Heroku::JSPlugin.app_dir).to eq(File.join("bar", "heroku"))
      end

      it "should not use XDG_DATA_HOME if defined" do
        allow(ENV).to receive(:[]).with("XDG_DATA_HOME").and_return("bar")
        expect(Heroku::JSPlugin.app_dir).to eq(File.join("bar", "heroku"))
      end

      it "should default to home directory" do
        expect(Heroku::JSPlugin.app_dir).to eq(File.join(Heroku::Helpers.home_directory, ".local", "share", "heroku"))
      end

      after do
        allow(Heroku::JSPlugin).to receive(:windows?).and_call_original
        allow(ENV).to receive(:[]).and_call_original
      end
    end
  end
end
