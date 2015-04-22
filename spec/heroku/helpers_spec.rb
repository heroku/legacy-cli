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

  end
end
