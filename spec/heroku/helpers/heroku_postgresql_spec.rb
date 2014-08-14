require "spec_helper"
require "heroku/helpers/heroku_postgresql"

include Heroku::Helpers::HerokuPostgresql

describe Heroku::Helpers::HerokuPostgresql::Resolver do

  before do
    @resolver = described_class.new('appname', double(:api))
    allow(@resolver).to receive(:app_config_vars) { app_config_vars }
    allow(@resolver).to receive(:app_attachments) { app_attachments }
  end

  let(:app_config_vars) do
    {
      "DATABASE_URL"                => "postgres://default",
      "HEROKU_POSTGRESQL_BLACK_URL" => "postgres://black",
      "HEROKU_POSTGRESQL_IVORY_URL" => "postgres://default"
    }
  end

    let(:app_attachments) {
      [ Attachment.new({ 'name'  => 'HEROKU_POSTGRESQL_IVORY',
                         'config_var' => 'HEROKU_POSTGRESQL_IVORY_URL',
                         'app' => {'name' => 'sushi' },
                         'resource' => {'name'  => 'softly-mocking-123',
                                        'value' => 'postgres://default',
                                        'type'  => 'heroku-postgresql:baku' }}),
        Attachment.new({ 'name'  => 'HEROKU_POSTGRESQL_BLACK',
                         'config_var' => 'HEROKU_POSTGRESQL_BLACK_URL',
                         'app' => {'name' => 'sushi' },
                         'resource' => {'name'  => 'quickly-yelling-2421',
                                        'value' => 'postgres://black',
                                        'type'  => 'heroku-postgresql:zilla' }})
      ]
    }

  context "when the DATABASE_URL has query options" do
    let(:app_config_vars) do
      {
        "DATABASE_URL"                => "postgres://default?pool=15",
        "HEROKU_POSTGRESQL_BLACK_URL" => "postgres://black",
        "HEROKU_POSTGRESQL_IVORY_URL" => "postgres://default",
        "SHARED_DATABASE_URL"         => "postgres://shared"
      }
    end

    it "resolves DATABASE" do
      att = @resolver.resolve('DATABASE')
      expect(att.display_name).to eq("HEROKU_POSTGRESQL_IVORY_URL (DATABASE_URL)")
      expect(att.url).to eq("postgres://default")
    end
  end

  context "when no app is specified or inferred, and identifier does not have app::db shorthand" do
    it 'exits, complaining about the missing app' do
      api = double('api')
      allow(api).to receive(:get_attachments).and_raise("getting this far will cause an inaccurate 'internal server error' message")

      no_app_resolver = described_class.new(nil, api)
      expect(no_app_resolver).to receive(:error).with(/No app specified/).and_raise(SystemExit)
      expect { no_app_resolver.resolve('black') }.to raise_error(SystemExit)
    end
  end

  context "when the identifier has ::" do
    it 'changes the resolver app to the left of the ::' do
      expect(@resolver.app_name).to eq('appname')
      att = @resolver.resolve('app2::black')
      expect(@resolver.app_name).to eq('app2')
    end

    it 'resolves database names on the right of the ::' do
      att = @resolver.resolve('app2::black')
      expect(att.url).to eq("postgres://black") # since we're mocking out the app_config_vars
    end

    it 'looks allows nothing after the :: to use the default' do
      att = @resolver.resolve('app2::', 'DATABASE_URL')
      expect(att.url).to eq("postgres://default")
    end
  end

  context "when the DATABASE_URL has no query options" do
    let(:app_config_vars) do
      {
        "DATABASE_URL"                => "postgres://default",
        "HEROKU_POSTGRESQL_BLACK_URL" => "postgres://black",
        "HEROKU_POSTGRESQL_IVORY_URL" => "postgres://default",
        "SHARED_DATABASE_URL"         => "postgres://shared"
      }
    end

    it "resolves DATABASE" do
      att = @resolver.resolve('DATABASE')
      expect(att.display_name).to eq("HEROKU_POSTGRESQL_IVORY_URL (DATABASE_URL)")
      expect(att.url).to eq("postgres://default")
    end
  end

  it "resolves default using NAME" do
    att = @resolver.resolve('IVORY')
    expect(att.display_name).to eq("HEROKU_POSTGRESQL_IVORY_URL (DATABASE_URL)")
    expect(att.url).to eq("postgres://default")
  end

  it "resolves non-default using NAME" do
    att = @resolver.resolve('BLACK')
    expect(att.display_name).to eq("HEROKU_POSTGRESQL_BLACK_URL")
    expect(att.url).to eq("postgres://black")
  end

  it "resolves default using NAME_URL" do
    att = @resolver.resolve('IVORY_URL')
    expect(att.display_name).to eq("HEROKU_POSTGRESQL_IVORY_URL (DATABASE_URL)")
    expect(att.url).to eq("postgres://default")
  end

  it "resolves non-default using NAME_URL" do
    att = @resolver.resolve('BLACK_URL')
    expect(att.display_name).to eq("HEROKU_POSTGRESQL_BLACK_URL")
    expect(att.url).to eq("postgres://black")
  end

  it "resolves default using lowercase" do
    att = @resolver.resolve('ivory')
    expect(att.display_name).to eq("HEROKU_POSTGRESQL_IVORY_URL (DATABASE_URL)")
    expect(att.url).to eq("postgres://default")
  end

  it "resolves non-default using lowercase" do
    att = @resolver.resolve('black')
    expect(att.display_name).to eq("HEROKU_POSTGRESQL_BLACK_URL")
    expect(att.url).to eq("postgres://black")
  end

  it "resolves non-default using part of name" do
    att = @resolver.resolve('bla')
    expect(att.display_name).to eq("HEROKU_POSTGRESQL_BLACK_URL")
    expect(att.url).to eq("postgres://black")
  end

  it "throws an error if it doesnt exist" do
    expect(@resolver).to receive(:error).with("Unknown database: violet. Valid options are: DATABASE_URL, HEROKU_POSTGRESQL_BLACK_URL, HEROKU_POSTGRESQL_IVORY_URL")
    @resolver.resolve("violet")
  end

  context "default" do

    it "errors if there is no default" do
      expect(@resolver).to receive(:error).with("Unknown database. Valid options are: DATABASE_URL, HEROKU_POSTGRESQL_BLACK_URL, HEROKU_POSTGRESQL_IVORY_URL")
      @resolver.resolve(nil)
    end

    it "uses the default if nothing(nil) specified" do
      att = @resolver.resolve(nil, "DATABASE_URL")
      expect(att.display_name).to eq("HEROKU_POSTGRESQL_IVORY_URL (DATABASE_URL)")
      expect(att.url).to eq("postgres://default")
    end

    it "uses the default if nothing(empty) specified" do
      att = @resolver.resolve('', "DATABASE_URL")
      expect(att.display_name).to eq("HEROKU_POSTGRESQL_IVORY_URL (DATABASE_URL)")
      expect(att.url).to eq("postgres://default")
    end

    it 'throws an error if given an empty string and asked for the default and there is no default' do
      app_config_vars.delete 'DATABASE_URL'
      expect(@resolver).to receive(:error).with("Unknown database. Valid options are: HEROKU_POSTGRESQL_BLACK_URL, HEROKU_POSTGRESQL_IVORY_URL")
      att = @resolver.resolve('', "DATABASE_URL")
    end

    it 'throws an error if given an empty string and asked for the default and the default doesnt match' do
      app_config_vars['DATABASE_URL'] = 'something different'
      expect(@resolver).to receive(:error).with("Unknown database. Valid options are: HEROKU_POSTGRESQL_BLACK_URL, HEROKU_POSTGRESQL_IVORY_URL")
      att = @resolver.resolve('', "DATABASE_URL")
    end


  end
end
