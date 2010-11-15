require File.expand_path("../base", File.dirname(__FILE__))

module Heroku::Command
  describe Pg do
    before do
      @pg = prepare_command(Pg)
      @pg.stub!(:config_vars).and_return({
        "DATABASE_URL" => "postgres://database_url"
      })
      @pg.stub!(:args).and_return(["--db", "DATABASE_URL"])
      @pg.heroku.stub!(:info).and_return({})
    end

    it "resets the app's database if user confirms" do
      @pg.stub!(:confirm_command).and_return(true)

      fake_client = mock("heroku_postgresql_client")
      fake_client.should_receive("reset")

      @pg.should_receive(:heroku_postgresql_client).with("postgres://database_url").and_return(fake_client)

      @pg.reset
    end

    it "doesn't reset the app's database if the user doesn't confirms" do
      @pg.stub!(:confirm_command).and_return(false)
      @pg.should_not_receive(:heroku_postgresql_client)
      @pg.reset
    end

  end
end
