require "spec_helper"
require "heroku/updater"

module Heroku
  describe Updater do

    it "calculates maximum_version" do
      Heroku::Updater.maximum_version('1.1.1', '1.1.1').should == '1.1.1'

      Heroku::Updater.maximum_version('2.1.1', '1.1.1').should == '2.1.1'
      Heroku::Updater.maximum_version('1.1.1', '2.1.1').should == '2.1.1'

      Heroku::Updater.maximum_version('1.2.1', '1.1.1').should == '1.2.1'
      Heroku::Updater.maximum_version('1.1.1', '1.2.1').should == '1.2.1'

      Heroku::Updater.maximum_version('1.1.2', '1.1.1').should == '1.1.2'
      Heroku::Updater.maximum_version('1.1.1', '1.1.2').should == '1.1.2'

      Heroku::Updater.maximum_version('1.2.1', '2.1.1').should == '2.1.1'
      Heroku::Updater.maximum_version('2.1.1', '1.2.1').should == '2.1.1'

      Heroku::Updater.maximum_version('1.1.2', '2.1.1').should == '2.1.1'
      Heroku::Updater.maximum_version('2.1.1', '1.1.2').should == '2.1.1'

      Heroku::Updater.maximum_version('1.2.3', '1.2.4').should == '1.2.4'
      Heroku::Updater.maximum_version('1.2.4', '1.2.3').should == '1.2.4'

      Heroku::Updater.maximum_version('1.2',   '1.2.1').should == '1.2.1'
      Heroku::Updater.maximum_version('1.2.1', '1.2'  ).should == '1.2.1'

      Heroku::Updater.maximum_version('1.1.1', '1.1.1.pre1').should == '1.1.1.pre1'
      Heroku::Updater.maximum_version('1.1.1.pre1', '1.1.1').should == '1.1.1.pre1'

      Heroku::Updater.maximum_version('1.1.1.pre1', '1.1.1.pre2').should == '1.1.1.pre2'
      Heroku::Updater.maximum_version('1.1.1.pre2', '1.1.1.pre1').should == '1.1.1.pre2'
    end

  end
end
