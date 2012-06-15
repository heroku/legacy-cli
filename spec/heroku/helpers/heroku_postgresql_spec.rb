require "spec_helper"
require "heroku/helpers/heroku_postgresql"

include Heroku::Helpers::HerokuPostgresql

describe Heroku::Helpers::HerokuPostgresql do

  before do
    subject.stub(:app_config_vars) { app_config_vars }
  end

  let(:app_config_vars) do
    {
      "DATABASE_URL"                => "postgres://default",
      "HEROKU_POSTGRESQL_BLACK_URL" => "postgres://black",
      "HEROKU_POSTGRESQL_IVORY_URL" => "postgres://default",
      "SHARED_DATABASE_URL"         => "postgres://shared"
    }
  end

  it "resolves DATABASE" do
    subject.hpg_resolve('DATABASE').should == [
      "HEROKU_POSTGRESQL_IVORY (DATABASE_URL)",
      "postgres://default"
    ]
  end

  it "resolves SHARED_DATABASE" do
    subject.hpg_resolve('SHARED_DATABASE').should == [
      "SHARED_DATABASE",
      "postgres://shared"
    ]
  end

  it "resolves default using NAME" do
    subject.hpg_resolve("IVORY").should == [
      "HEROKU_POSTGRESQL_IVORY (DATABASE_URL)",
      "postgres://default"
    ]
  end

  it "resolves non-default using NAME" do
    subject.hpg_resolve("BLACK").should == [
      "HEROKU_POSTGRESQL_BLACK",
      "postgres://black"
    ]
  end

  it "resolves default using NAME_URL" do
    subject.hpg_resolve("IVORY_URL").should == [
      "HEROKU_POSTGRESQL_IVORY (DATABASE_URL)",
      "postgres://default"
    ]
  end

  it "resolves non-default using NAME_URL" do
    subject.hpg_resolve("BLACK_URL").should == [
      "HEROKU_POSTGRESQL_BLACK",
      "postgres://black"
    ]
  end

  it "resolves default using lowercase" do
    subject.hpg_resolve("ivory").should == [
      "HEROKU_POSTGRESQL_IVORY (DATABASE_URL)",
      "postgres://default"
    ]
  end

  it "resolves non-default using lowercase" do
    subject.hpg_resolve("black").should == [
      "HEROKU_POSTGRESQL_BLACK",
      "postgres://black"
    ]
  end

  it "throws an error if it doesnt exist" do
    subject.should_receive(:error).with("Unknown database: VIOLET. Valid options are: DATABASE, HEROKU_POSTGRESQL_BLACK, HEROKU_POSTGRESQL_IVORY, SHARED_DATABASE")
    subject.hpg_resolve("violet")
  end

  context "default" do

    it "errors if there is no default" do
      subject.should_receive(:error).with("Unknown database. Valid options are: DATABASE, HEROKU_POSTGRESQL_BLACK, HEROKU_POSTGRESQL_IVORY, SHARED_DATABASE")
      subject.hpg_resolve(nil)
    end

    it "uses the default if nothing specified" do
      subject.hpg_resolve(nil, "DATABASE_URL").should == [
        "HEROKU_POSTGRESQL_IVORY (DATABASE_URL)",
        "postgres://default"
      ]
    end

  end

  context "uri" do

    it "returns the uri directly" do
      subject.hpg_resolve('postgres://uri', nil).should == [
        nil,
        'postgres://uri'
      ]
    end

  end

end
