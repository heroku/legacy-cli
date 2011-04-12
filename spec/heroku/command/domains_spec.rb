require "spec_helper"
require "heroku/command/domains"

module Heroku::Command
  describe Domains do
    before do
      @domains = prepare_command(Domains)
    end

    it "lists domains" do
      @domains.heroku.should_receive(:list_domains).and_return([])
      @domains.index
    end

    it "adds domain names" do
      @domains.stub!(:args).and_return(['example.com'])
      @domains.heroku.should_receive(:add_domain).with('myapp', 'example.com')
      @domains.add
    end

    it "removes domain names" do
      @domains.stub!(:args).and_return(['example.com'])
      @domains.heroku.should_receive(:remove_domain).with('myapp', 'example.com')
      @domains.remove
    end

    it "removes all domain names" do
      @domains.heroku.should_receive(:remove_domains).with('myapp')
      @domains.clear
    end
  end
end
