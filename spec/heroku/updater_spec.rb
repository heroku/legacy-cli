require "spec_helper"
require "heroku/updater"
require "heroku/version"

module Heroku
  describe Updater do

    before do
      allow(subject).to receive(:stderr_puts)
      allow(subject).to receive(:stderr_print)
    end

    describe('::latest_local_version') do
      it 'calculates the latest local version' do
        expect(subject.latest_local_version).to eq(Heroku::VERSION)
      end
    end

    describe('::compare_versions') do
      it 'calculates compare_versions' do
        expect(subject.compare_versions('1.1.1', '1.1.1')).to eq(0)

        expect(subject.compare_versions('2.1.1', '1.1.1')).to eq(1)
        expect(subject.compare_versions('1.1.1', '2.1.1')).to eq(-1)

        expect(subject.compare_versions('1.2.1', '1.1.1')).to eq(1)
        expect(subject.compare_versions('1.1.1', '1.2.1')).to eq(-1)

        expect(subject.compare_versions('1.1.2', '1.1.1')).to eq(1)
        expect(subject.compare_versions('1.1.1', '1.1.2')).to eq(-1)

        expect(subject.compare_versions('2.1.1', '1.2.1')).to eq(1)
        expect(subject.compare_versions('1.2.1', '2.1.1')).to eq(-1)

        expect(subject.compare_versions('2.1.1', '1.1.2')).to eq(1)
        expect(subject.compare_versions('1.1.2', '2.1.1')).to eq(-1)

        expect(subject.compare_versions('1.2.4', '1.2.3')).to eq(1)
        expect(subject.compare_versions('1.2.3', '1.2.4')).to eq(-1)

        expect(subject.compare_versions('1.2.1', '1.2'  )).to eq(1)
        expect(subject.compare_versions('1.2',   '1.2.1')).to eq(-1)

        expect(subject.compare_versions('1.1.1.pre1', '1.1.1')).to eq(1)
        expect(subject.compare_versions('1.1.1', '1.1.1.pre1')).to eq(-1)

        expect(subject.compare_versions('1.1.1.pre2', '1.1.1.pre1')).to eq(1)
        expect(subject.compare_versions('1.1.1.pre1', '1.1.1.pre2')).to eq(-1)
      end
    end

    describe '::update' do
      before do
        Excon.stub({:host => 'assets.heroku.com', :path => '/heroku-client/VERSION'}, {:body => "3.9.7\n"})
      end

      describe 'non-beta' do
        before do
          zip = File.read(File.expand_path('../../fixtures/heroku-client-3.9.7.zip', __FILE__))
          hash = "615792e1f06800a6d744f518887b10c09aa914eab51d0f7fbbefd81a8a64af93"
          Excon.stub({:host => 'toolbelt.heroku.com', :path => '/download/zip'}, {:body => zip})
          Excon.stub({:host => 'toolbelt.heroku.com', :path => '/update/hash'}, {:body => "#{hash}\n"})
        end

        context 'with no update available' do
          before do
            allow(subject).to receive(:latest_local_version).and_return('3.9.7')
          end

          it 'does not update' do
            expect(subject.update(false)).to be_nil
          end
        end

        context 'with an update available' do
          before do
            allow(subject).to receive(:latest_local_version).and_return('3.9.6')
          end

          it 'updates' do
            expect(subject.update(false)).to eq('3.9.7')
          end
        end
      end

      describe 'beta' do
        before do
          zip = File.read(File.expand_path('../../fixtures/heroku-client-3.9.7.zip', __FILE__))
          Excon.stub({:host => 'toolbelt.heroku.com', :path => '/download/beta-zip'}, {:body => zip})
        end

        context 'with no update available' do
          before do
            allow(subject).to receive(:latest_local_version).and_return('3.9.7')
          end

          it 'still updates' do
            expect(subject.update(true)).to eq('3.9.7')
          end
        end

        context 'with a beta older than what we have' do
          before do
            allow(subject).to receive(:latest_local_version).and_return('3.9.8')
          end

          it 'does not update' do
            expect(subject.update(true)).to be_nil
          end
        end
      end
    end
  end
end
