require "spec_helper"
require "heroku/helpers"

module Heroku
  describe Helpers do
    include Heroku::Helpers

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
