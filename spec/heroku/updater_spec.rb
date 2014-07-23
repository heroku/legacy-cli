require "spec_helper"
require "heroku/updater"
require "heroku/version"

module Heroku
  describe Updater do

    it "calculates the latest local version" do
      expect(Heroku::Updater.latest_local_version).to eq(Heroku::VERSION)
    end

    it "calculates compare_versions" do
      expect(Heroku::Updater.compare_versions('1.1.1', '1.1.1')).to eq 0

      expect(Heroku::Updater.compare_versions('2.1.1', '1.1.1')).to eq 1
      expect(Heroku::Updater.compare_versions('1.1.1', '2.1.1')).to eq -1

      expect(Heroku::Updater.compare_versions('1.2.1', '1.1.1')).to eq 1
      expect(Heroku::Updater.compare_versions('1.1.1', '1.2.1')).to eq -1

      expect(Heroku::Updater.compare_versions('1.1.2', '1.1.1')).to eq 1
      expect(Heroku::Updater.compare_versions('1.1.1', '1.1.2')).to eq -1

      expect(Heroku::Updater.compare_versions('2.1.1', '1.2.1')).to eq 1
      expect(Heroku::Updater.compare_versions('1.2.1', '2.1.1')).to eq -1

      expect(Heroku::Updater.compare_versions('2.1.1', '1.1.2')).to eq 1
      expect(Heroku::Updater.compare_versions('1.1.2', '2.1.1')).to eq -1

      expect(Heroku::Updater.compare_versions('1.2.4', '1.2.3')).to eq 1
      expect(Heroku::Updater.compare_versions('1.2.3', '1.2.4')).to eq -1

      expect(Heroku::Updater.compare_versions('1.2.1', '1.2'  )).to eq 1
      expect(Heroku::Updater.compare_versions('1.2',   '1.2.1')).to eq -1

      expect(Heroku::Updater.compare_versions('1.1.1.pre1', '1.1.1')).to eq 1
      expect(Heroku::Updater.compare_versions('1.1.1', '1.1.1.pre1')).to eq -1

      expect(Heroku::Updater.compare_versions('1.1.1.pre2', '1.1.1.pre1')).to eq 1
      expect(Heroku::Updater.compare_versions('1.1.1.pre1', '1.1.1.pre2')).to eq -1
    end

  end
end
