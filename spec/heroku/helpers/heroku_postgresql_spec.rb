require "spec_helper"
require "heroku/helpers/heroku_postgresql"

include Heroku::Helpers::HerokuPostgresql

describe Heroku::Helpers::HerokuPostgresql do

  before do
    subject.stub(:app_config_vars) { app_config_vars }
  end

  let(:app_config_vars) do
    { "DATABASE_URL" => "postgres://default", "HEROKU_POSTGRESQL_BLACK_URL" => "postgres://black" }
  end

  it "resolves using NAME" do
    subject.hpg_resolve("BLACK").last.should == "postgres://black"
  end

  it "resolves using NAME_URL" do
    subject.hpg_resolve("BLACK_URL").last.should == "postgres://black"
  end

  it "resolves using lowercase" do
    subject.hpg_resolve("black").last.should == "postgres://black"
  end

  it "throws an error if it doesnt exist" do
    subject.should_receive(:error).with("Unknown database: VIOLET. Valid options are: HEROKU_POSTGRESQL_BLACK")
    subject.hpg_resolve("violet")
  end

  context "default" do

    it "errors if there is no default" do
      subject.should_receive(:error).with("Unknown database. Valid options are: HEROKU_POSTGRESQL_BLACK")
      subject.hpg_resolve(nil)
    end

    it "uses the default if nothing specified" do
      subject.hpg_resolve(nil, "DATABASE_URL").last.should == "postgres://default"
    end

  end

end
