require 'spec_helper'
require 'heroku/updater'

describe Heroku::Updater do
  context 'a user has no home directory' do
    before do
      @env = Object.send(:remove_const, :ENV)
      ENV = {}
    end

    after do
      Object.send(:remove_const, :ENV)
      ENV = @env
    end

    describe '.updated_client_path' do
      it 'does not blow up if the user is executing with out a HOME directory' do
        expect{
          Heroku::Updater.updated_client_path
        }.should_not raise_error
      end
    end

    describe '.home_directory' do
      it 'should default to an empty string' do
        Heroku::Updater.home_directory.should == ''
      end
    end
  end
end
