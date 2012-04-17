require "spec_helper"
require "heroku/command/keys"

module Heroku::Command
  describe Keys do

    context("add") do

      it "tries to find a key if no key filename is supplied" do
        Heroku::Auth.should_receive(:get_credentials)
        Heroku::Auth.should_receive(:ask).and_return("y")
        Heroku::Auth.should_receive(:generate_ssh_key)
        File.should_receive(:read).with('/.ssh/id_rsa.pub').and_return('ssh-rsa xyz')
        stub_core.add_key("ssh-rsa xyz")
        stderr, stdout = execute("keys:add")
        stderr.should == ""
        stdout.should == <<-STDOUT
Could not find an existing public key.
Would you like to generate one? [Yn] Generating new SSH public key.
Uploading SSH public key /.ssh/id_rsa.pub
STDOUT
      end

      it "adds a key from a specified keyfile path" do
        stub_core.add_key('ssh-rsa xyz')
        File.should_receive(:read).with('/my/key.pub').and_return('ssh-rsa xyz')
        stderr, stdout = execute("keys:add /my/key.pub")
        stderr.should == ""
        stdout.should == <<-STDOUT
Uploading SSH public key /my/key.pub
STDOUT
      end

    end

    context("index") do

      before do
        stub_core.keys.returns(["ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku\n"])
      end

      it "list keys, trimming the hex code for better display" do
        stderr, stdout = execute("keys")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== 1 key for user
ssh-rsa AAAAB3NzaC...Fyoke4MQ== pedro@heroku
STDOUT
      end

      it "list keys showing the whole key hex with --long" do
        stderr, stdout = execute("keys --long")
        stderr.should == ""
        stdout.should == <<-STDOUT
=== 1 key for user
ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku
STDOUT
      end

    end
  end
end
