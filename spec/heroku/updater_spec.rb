require "spec_helper"
require "heroku/updater"
require "heroku/version"

module Heroku
  describe Updater do

    it "calculates the latest local version" do
      Heroku::Updater.latest_local_version.should == Heroku::VERSION
    end

    it "calculates compare_versions" do
      Heroku::Updater.compare_versions('1.1.1', '1.1.1').should == 0

      Heroku::Updater.compare_versions('2.1.1', '1.1.1').should == 1
      Heroku::Updater.compare_versions('1.1.1', '2.1.1').should == -1

      Heroku::Updater.compare_versions('1.2.1', '1.1.1').should == 1
      Heroku::Updater.compare_versions('1.1.1', '1.2.1').should == -1

      Heroku::Updater.compare_versions('1.1.2', '1.1.1').should == 1
      Heroku::Updater.compare_versions('1.1.1', '1.1.2').should == -1

      Heroku::Updater.compare_versions('2.1.1', '1.2.1').should == 1
      Heroku::Updater.compare_versions('1.2.1', '2.1.1').should == -1

      Heroku::Updater.compare_versions('2.1.1', '1.1.2').should == 1
      Heroku::Updater.compare_versions('1.1.2', '2.1.1').should == -1

      Heroku::Updater.compare_versions('1.2.4', '1.2.3').should == 1
      Heroku::Updater.compare_versions('1.2.3', '1.2.4').should == -1

      Heroku::Updater.compare_versions('1.2.1', '1.2'  ).should == 1
      Heroku::Updater.compare_versions('1.2',   '1.2.1').should == -1

      Heroku::Updater.compare_versions('1.1.1.pre1', '1.1.1').should == 1
      Heroku::Updater.compare_versions('1.1.1', '1.1.1.pre1').should == -1

      Heroku::Updater.compare_versions('1.1.1.pre2', '1.1.1.pre1').should == 1
      Heroku::Updater.compare_versions('1.1.1.pre1', '1.1.1.pre2').should == -1
    end

  end
end
