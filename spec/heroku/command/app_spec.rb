require "spec_helper"
require "heroku/command/app"

module Heroku::Command
  describe App do
    before(:each) do
      @cli = prepare_command(App)
      @cli.stub(:options).and_return(:app => "myapp")
    end
  end
end
