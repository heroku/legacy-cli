require 'spec_helper'
require 'heroku/command/git'

module Heroku::Command
  describe Git do

    before(:each) do
      stub_core
    end

    context("clone") do

      before(:each) do
        api.post_app("name" => "example", "stack" => "cedar")
      end

      after(:each) do
        api.delete_app("example")
      end

      it "clones and adds remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          mock(git).system("git clone -o heroku git@heroku.com:example.git") do
            puts "Cloning into 'example'..."
          end
        end
        stderr, stdout = execute("git:clone example")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning from app 'example'...
Cloning into 'example'...
        STDOUT
      end

      it "clones into another dir" do
        any_instance_of(Heroku::Command::Git) do |git|
          mock(git).system("git clone -o heroku git@heroku.com:example.git somedir") do
            puts "Cloning into 'somedir'..."
          end
        end
        stderr, stdout = execute("git:clone example somedir")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning from app 'example'...
Cloning into 'somedir'...
        STDOUT
      end

      it "can specify app with -a" do
        any_instance_of(Heroku::Command::Git) do |git|
          mock(git).system("git clone -o heroku git@heroku.com:example.git") do
            puts "Cloning into 'example'..."
          end
        end
        stderr, stdout = execute("git:clone -a example")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning from app 'example'...
Cloning into 'example'...
        STDOUT
      end

      it "can specify app with -a and a dir" do
        any_instance_of(Heroku::Command::Git) do |git|
          mock(git).system("git clone -o heroku git@heroku.com:example.git somedir") do
            puts "Cloning into 'somedir'..."
          end
        end
        stderr, stdout = execute("git:clone -a example somedir")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning from app 'example'...
Cloning into 'somedir'...
        STDOUT
      end

      it "clones and sets -r remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          mock(git).system("git clone -o other git@heroku.com:example.git") do
            puts "Cloning into 'example'..."
          end
        end
        stderr, stdout = execute("git:clone example -r other")
        stderr.should == ""
        stdout.should == <<-STDOUT
Cloning from app 'example'...
Cloning into 'example'...
        STDOUT
      end

    end

    context("remote") do

      before(:each) do
        api.post_app("name" => "example", "stack" => "cedar")
        FileUtils.mkdir('example')
        FileUtils.chdir('example') { `git init` }
      end

      after(:each) do
        api.delete_app("example")
        FileUtils.rm_rf('example')
      end

      it "adds remote" do
        any_instance_of(Heroku::Command::Git) do |git|
          stub(git).git('remote').returns("origin")
          stub(git).git('remote add heroku git@heroku.com:example.git')
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
          stub(git).git('remote add other git@heroku.com:example.git')
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
