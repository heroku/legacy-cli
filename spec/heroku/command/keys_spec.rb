require "spec_helper"
require "heroku/command/keys"

module Heroku::Command
  describe Keys do
    KEY = "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== pedro@heroku"

    before(:each) do
      stub_core
      allow(Heroku::Auth).to receive(:home_directory).and_return(Heroku::Helpers.home_directory)
    end

    context("add") do
      it "tries to find a key if no key filename is supplied" do
        expect(Heroku::Auth).to receive(:ask).and_return("y")
        stderr, stdout = execute("keys:add")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Could not find an existing public key at ~/.ssh/id_rsa.pub
Would you like to generate one? [Yn] Generating new SSH public key.
Uploading SSH public key #{Heroku::Auth.home_directory}/.ssh/id_rsa.pub... done
STDOUT
        api.delete_key(`whoami`.strip + '@' + `hostname`.strip)
      end

      it "adds a key from a specified keyfile path" do
        # This is because the JSPlugin makes a call to File.exists
        # Not pretty, but will always work and should be temporary
        allow(Heroku::JSPlugin).to receive(:setup?).and_return(false)
        expect(File).to receive(:exists?).with('.git').and_return(false)
        expect(File).to receive(:exists?).with('/my/key.pub').and_return(true)
        expect(File).to receive(:read).with('/my/key.pub').and_return(KEY)
        stderr, stdout = execute("keys:add /my/key.pub")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Uploading SSH public key /my/key.pub... done
STDOUT
        api.delete_key("pedro@heroku")
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
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
=== email@example.com Keys
ssh-rsa AAAAB3NzaC...Fyoke4MQ== pedro@heroku

STDOUT
      end

      it "list keys showing the whole key hex with --long" do
        stderr, stdout = execute("keys --long")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
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
          expect(stderr).to eq("")
          expect(stdout).to eq <<-STDOUT
Removing pedro@heroku SSH key... done
STDOUT
        end

      end

      it "displays an error if no key is specified" do
        stderr, stdout = execute("keys:remove")
        expect(stderr).to eq <<-STDERR
 !    Usage: heroku keys:remove KEY
 !    Must specify KEY to remove.
STDERR
        expect(stdout).to eq("")
      end

    end

    context("clear") do

      it "succeeds" do
        stderr, stdout = execute("keys:clear")
        expect(stderr).to eq("")
        expect(stdout).to eq <<-STDOUT
Removing all SSH keys... done
STDOUT
      end

    end

  end
end
