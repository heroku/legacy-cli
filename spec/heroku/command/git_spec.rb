require 'spec_helper'
require 'heroku/command/git'

module Heroku::Command
  describe Git do

    before(:each) do
      stub_core
    end

    context("clone") do

      before(:each) do
        api.post_app("name" => "myapp", "stack" => "cedar")
        FileUtils.mkdir('myapp')
        FileUtils.chdir('myapp') { `git init` }
      end

      after(:each) do
        api.delete_app("myapp")
        FileUtils.rm_rf('myapp')
      end

      it "clones and adds remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          stub(git).git('clone git@heroku.com:myapp.git ').returns("Cloning into 'myapp'...")
          stub(git).git('remote').returns("origin")
          stub(git).git('remote add heroku git@heroku.com:myapp.git')
        end
        stderr, stdout = execute("git:clone")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning into 'myapp'...
Git remote heroku added
        STDOUT
      end

      it "clones and sets -r remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          stub(git).git('clone git@heroku.com:myapp.git ').returns("Cloning into 'myapp'...")
          stub(git).git('remote').returns("origin")
          stub(git).git('remote add other git@heroku.com:myapp.git')
        end
        stderr, stdout = execute("git:clone -r other")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning into 'myapp'...
Git remote other added
        STDOUT
      end

      it "clones and skips remote with no-remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          stub(git).git('clone git@heroku.com:myapp.git ').returns("Cloning into 'myapp'...")
        end
        stderr, stdout = execute("git:clone --no-remote")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning into 'myapp'...
        STDOUT
      end

    end

    context("remote") do

      before(:each) do
        api.post_app("name" => "myapp", "stack" => "cedar")
        FileUtils.mkdir('myapp')
        FileUtils.chdir('myapp') { `git init` }
      end

      after(:each) do
        api.delete_app("myapp")
        FileUtils.rm_rf('myapp')
      end

      it "adds remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          stub(git).git('remote').returns("origin")
          stub(git).git('remote add heroku git@heroku.com:myapp.git')
        end
        stderr, stdout = execute("git:remote")
        stderr.should == ""
        stdout.should == <<-STDOUT
Git remote heroku added
        STDOUT
      end

      it "adds -r remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          stub(git).git('remote').returns("origin")
          stub(git).git('remote add other git@heroku.com:myapp.git')
        end
        stderr, stdout = execute("git:remote -r other")
        stderr.should == ""
        stdout.should == <<-STDOUT
Git remote other added
        STDOUT
      end

      it "skips remote when it already exists" do
        any_instance_of(Heroku::Command::Git) do |git|
          stub(git).git('remote').returns("heroku")
        end
        stderr, stdout = execute("git:remote")
        stderr.should == <<-STDERR
 !    Git remote heroku already exists
STDERR
        stdout.should == ""
      end

    end

  end
end
