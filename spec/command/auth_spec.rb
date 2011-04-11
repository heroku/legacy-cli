require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Auth do
    before(:each) do
      @cli = prepare_command(Auth)
    end
  end
end
