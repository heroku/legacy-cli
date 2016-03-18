require "spec_helper"
require "heroku/helpers"

module Heroku
  describe Helpers do
    include Heroku::Helpers

    context "time_remaining" do
      it "should display seconds remaining correctly" do
        now = Time.now
        future = Time.now + 30
        expect(time_remaining(now, future)).to eq("30s")
      end

      it "should display minutes remaining correctly" do
        now = Time.now
        future = Time.now + 65
        expect(time_remaining(now, future)).to eq("1m 5s")
      end

      it "should display hours remaining correctly" do
        now = Time.now
        future = Time.now + (70*60)
        expect(time_remaining(now, future)).to eq("1h 10m")
      end
    end

    context "display_object" do

      it "should display Array correctly" do
        expect(capture_stdout do
          display_object([1,2,3])
        end).to eq <<-OUT
1
2
3
OUT
      end

      it "should display { :header => [] } list correctly" do
        expect(capture_stdout do
          display_object({:first_header => [1,2,3], :last_header => [7,8,9]})
        end).to eq <<-OUT
=== first_header
1
2
3

=== last_header
7
8
9

OUT
      end

      it "should display String properly" do
        expect(capture_stdout do
          display_object('string')
        end).to eq <<-OUT
string
OUT
      end

    end

    context "home_directory" do
      before do
        allow(Heroku::Helpers).to receive(:running_on_windows?).and_return(true)

        # I would much rather have removed / set ENV variables here, 
        # but things get manged by the []= operator in windows.
        #
        # ENV['f'] = "\u0412" ; ENV['f'].encoding == ASCII-8BIT
        allow(ENV).to receive(:[]).and_return(nil)

        @tmp_dir = Dir.mktmpdir.encode('utf-8')
        @home_dir = File.join(@tmp_dir, "\u0412")
        @windows_home_dir = @home_dir.gsub(/\//, "\\")
        Dir.mkdir(@home_dir)
      end

      after do
        allow(Heroku::Helpers).to receive(:running_on_windows?).and_call_original
        allow(ENV).to receive(:[]).and_call_original

        Dir.rmdir(@home_dir)
        Dir.rmdir(@tmp_dir)
      end

      it "should throw ArgumentError when nothing is defined" do
        expect{ Heroku::Helpers.orig_home_directory }.to raise_error(ArgumentError)
      end

      it "should handle crillic characters properly in HOME" do
        allow(ENV).to receive(:[]).with("HOME").and_return(@windows_home_dir)
        allow(ENV).to receive(:[]).with("HOMEPATH").and_return("foo")
        allow(ENV).to receive(:[]).with("HOMEDRIVE").and_return("bar")
        allow(ENV).to receive(:[]).with("USERPROFILE").and_return("biz")
        expect(Heroku::Helpers.orig_home_directory).to eq(@home_dir)
      end

      it "should not use HOMEDRIVE when HOMEPATH is not defined" do
        allow(ENV).to receive(:[]).with("HOMEDRIVE").and_return(@windows_home_dir[0..1])
        expect{ Heroku::Helpers.orig_home_directory }.to raise_error(ArgumentError)
      end

      it "should handle crillic characters properly in HOMEDRIVE / HOMEPATH" do
        allow(ENV).to receive(:[]).with("HOMEDRIVE").and_return(@windows_home_dir[0..1])
        allow(ENV).to receive(:[]).with("HOMEPATH").and_return(@windows_home_dir[2..-1])
        allow(ENV).to receive(:[]).with("USERPROFILE").and_return("biz")
        expect(Heroku::Helpers.orig_home_directory).to eq(@home_dir)
      end

      it "should handle crillic characters properly in USERPROFILE" do
        allow(ENV).to receive(:[]).with("USERPROFILE").and_return(@windows_home_dir)
        expect(Heroku::Helpers.orig_home_directory).to eq(@home_dir)
      end
    end

    context "home_directory (compatibility)" do
      before do
        allow(Heroku::Helpers).to receive(:running_on_windows?).and_return(true)

        # I would much rather have removed / set ENV variables here, 
        # but things get manged by the []= operator in windows.
        #
        # ENV['f'] = "\u0412" ; ENV['f'].encoding == ASCII-8BIT
        @home = ENV.delete('HOME')
        @home_drive = ENV.delete('HOMEDRIVE')
        @home_path = ENV.delete('HOMEPATH')
        @user_profile = ENV.delete('USERPROFILE')

        @home_dir = Heroku::Helpers.home_directory
        @windows_home_dir = @home_dir.gsub(/\//, "\\")
      end

      after do
        allow(Heroku::Helpers).to receive(:running_on_windows?).and_call_original

        ENV['HOME'] = @home
        ENV['HOMEDRIVE'] = @home_drive
        ENV['HOMEPATH'] = @home_path
        ENV['USERPROFILE'] = @user_profile
      end

      it "should throw ArgumentError when nothing is defined" do
        expect{ Heroku::Helpers.orig_home_directory }.to raise_error(ArgumentError)
      end

      it "should use HOME" do
        ENV["HOME"] = @windows_home_dir
        ENV["HOMEPATH"] = "foo"
        ENV["HOMEDRIVE"] = "bar"
        ENV["USERPROFILE"] = "biz"
        expect(Heroku::Helpers.orig_home_directory).to eq(@home_dir)
      end

      it "should not use HOMEDRIVE when HOMEPATH is not defined" do
        ENV["HOMEDRIVE"] = @windows_home_dir[0..1]
        expect{ Heroku::Helpers.orig_home_directory }.to raise_error(ArgumentError)
      end

      it "should use HOMEDRIVE / HOMEPATH" do
        ENV["HOMEDRIVE"] = @windows_home_dir[0..1]
        ENV["HOMEPATH"] = @windows_home_dir[2..-1]
        ENV["USERPROFILE"] = "biz"
        expect(Heroku::Helpers.orig_home_directory).to eq(@home_dir)
      end

      it "should use USERPROFILE" do
        ENV["USERPROFILE"] = @windows_home_dir
        expect(Heroku::Helpers.orig_home_directory).to eq(@home_dir)
      end
    end

    context "format_with_bang" do
      it "should not fail with bad utf characters" do
        message = "hello joel\255".force_encoding('UTF-8')
        expect(" !    hello joel\u{FFFD}").to eq(format_with_bang(message))
      end
    end

  end
end
