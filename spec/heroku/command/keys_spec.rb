require "spec_helper"
require "heroku/command/keys"

module Heroku::Command
  describe Keys do
    KEY = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku"

    before(:each) do
      stub_core
    end

    context("add") do

      after(:each) do
        api.delete_key("pedro@heroku")
      end

      it "tries to find a key if no key filename is supplied" do
        Heroku::Auth.should_receive(:ask).and_return("y")
        Heroku::Auth.should_receive(:generate_ssh_key)
        File.should_receive(:exists?).with('.git').and_return(false)
        File.should_receive(:exists?).with('/.ssh/id_rsa.pub').and_return(true)
        File.should_receive(:read).with('/.ssh/id_rsa.pub').and_return(KEY)
        stderr, stdout = execute("keys:add")
        stderr.should == ""
        stdout.should == <<-STDOUT
Could not find an existing public key.
Would you like to generate one? [Yn] Generating new SSH public key.
Uploading SSH public key /.ssh/id_rsa.pub... done
STDOUT
      end

      it "adds a key from a specified keyfile path" do
        File.should_receive(:exists?).with('.git').and_return(false)
        File.should_receive(:exists?).with('/my/key.pub').and_return(true)
        File.should_receive(:read).with('/my/key.pub').and_return(KEY)
        stderr, stdout = execute("keys:add /my/key.pub")
        stderr.should == ""
        stdout.should == <<-STDOUT
Uploading SSH public key /my/key.pub... done
STDOUT
      end

    end

    context("index") do

      before do
        api.post_key(KEY)
      end

      after do
        api.delete_key("pedro@heroku")
      end

      it "list keys, trimming the hex code for better display" do
        stderr, stdout = execute("keys")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== email@example.com Keys
ssh-rsa AAAAB3NzaC...Fyoke4MQ== pedro@heroku

STDOUT
      end

      it "list keys showing the whole key hex with --long" do
        stderr, stdout = execute("keys --long")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== email@example.com Keys
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku

STDOUT
      end

    end

    context("remove") do

      context("success") do

        before(:each) do
          api.post_key(KEY)
        end

        it "succeeds" do
          stderr, stdout = execute("keys:remove pedro@heroku")
          stderr.should == ""
          stdout.should == <<-STDOUT
Removing pedro@heroku SSH key... done
STDOUT
        end

      end

      it "displays an error if no key is specified" do
        stderr, stdout = execute("keys:remove")
        stderr.should == <<-STDERR
 !    Usage: heroku keys:remove KEY
 !    Must specify KEY to remove.
STDERR
        stdout.should == ""
      end

    end

    context("clear") do

      it "succeeds" do
        stderr, stdout = execute("keys:clear")
        stderr.should == ""
        stdout.should == <<-STDOUT
Removing all SSH keys... done
STDOUT
      end

    end

  end
end
