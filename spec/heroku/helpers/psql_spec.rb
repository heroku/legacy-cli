require 'spec_helper'
require 'heroku/helpers/psql'

describe Helpers::PSQL do
  subject do
    attachment = double(:attachment,
                        :url => 'postgres://database',
                        :display_name => "HEROKU_POSTGRESQL_BROWN_URL",
                        :name => "HEROKU_POSTGRESQL_BROWN_URL",
                        :app => 'myapp')
    Helpers::PSQL.new(attachment)
  end

  describe '.exec_sql' do
    context 'without psql installed' do
      before do
        allow(subject).to receive(:status_code).and_return(32512)
      end

      it 'says psql is not installed' do
        expect(subject).to receive(:`).with("command psql -c \"SELECT VERSION();\"  -h database -p 5432 ")
        expect{subject.exec_sql('SELECT VERSION();')}.to raise_error("The local psql command could not be located")
      end
    end

    context 'with psql installed' do
      before do
        allow(subject).to receive(:status_code).and_return(0)
      end

      it 'says psql is not installed' do
        expect(subject).to receive(:`).with("command psql -c \"SELECT VERSION();\"  -h database -p 5432 ")
        expect{subject.exec_sql('SELECT VERSION();')}.to_not raise_error
      end
    end
  end

  describe '.shell' do
    it 'outputs the database name' do
      expect(subject).to receive(:exec).with('psql -U  -h database -p 5432 --set "PROMPT1=myapp::BROWN_URL%R%#" --set "PROMPT2=myapp::BROWN_URL%R%#"  ')
      _, stdout = execute('pg:psql')
      expect(stdout).to eq('foobar')
    end
  end
end
