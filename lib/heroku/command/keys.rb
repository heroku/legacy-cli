require "heroku/command/base"

module Heroku::Command

  # manage authentication keys
  #
  class Keys < Base

    # keys
    #
    # display keys for the current user
    #
    # -l, --long  # display extended information for each key
    #
    #Examples:
    #
    # $ heroku keys
    # === email@example.com Keys
    # ssh-rsa ABCDEFGHIJK...OPQRSTUV== email@example.com
    #
    # $ heroku keys --long
    # === email@example.com Keys
    # ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAp9AJD5QABmOcrkHm6SINuQkDefaR0MUrfgZ1Pxir3a4fM1fwa00dsUwbUaRuR7FEFD8n1E9WwDf8SwQTHtyZsJg09G9myNqUzkYXCmydN7oGr5IdVhRyv5ixcdiE0hj7dRnOJg2poSQ3Qi+Ka8SVJzF7nIw1YhuicHPSbNIFKi5s0D5a+nZb/E6MNGvhxoFCQX2IcNxaJMqhzy1ESwlixz45aT72mXYq0LIxTTpoTqma1HuKdRY8HxoREiivjmMQulYP+CxXFcMyV9kxTKIUZ/FXqlC6G5vSm3J4YScSatPOj9ID5HowpdlIx8F6y4p1/28r2tTl4CY40FFyoke4MQ== email@example.com
    #
    def index
      validate_arguments!
      keys = api.get_keys.body
      if keys.length > 0
        styled_header("#{Heroku::Auth.user} Keys")
        keys = if options[:long]
          keys.map {|key| key["contents"].strip}
        else
          keys.map {|key| format_key_for_display(key["contents"])}
        end
        styled_array(keys)
      else
        display("You have no keys.")
      end
    end

    # keys:add [KEY]
    #
    # add a key for the current user
    #
    # if no KEY is specified, will try to find ~/.ssh/id_[rd]sa.pub
    #
    #Examples:
    #
    # $ heroku keys:add
    # Could not find an existing public key.
    # Would you like to generate one? [Yn] y
    # Generating new SSH public key.
    # Uploading SSH public key /.ssh/id_rsa.pub... done
    #
    # $ heroku keys:add /my/key.pub
    # Uploading SSH public key /my/key.pub... done
    #
    def add
      keyfile = shift_argument
      validate_arguments!

      if keyfile
        Heroku::Auth.associate_key(keyfile)
      else
        # make sure we have credentials
        Heroku::Auth.get_credentials
        Heroku::Auth.associate_or_generate_ssh_key
      end
    end

    # keys:remove KEY
    #
    # remove a key from the current user
    #
    #Examples:
    #
    # $ heroku keys:remove email@example.com
    # Removing email@example.com SSH key... done
    #
    def remove
      key = shift_argument
      if key.nil? || key.empty?
        error("Usage: heroku keys:remove KEY\nMust specify KEY to remove.")
      end
      validate_arguments!

      action("Removing #{key} SSH key") do
        api.delete_key(key)
      end
    end

    # keys:clear
    #
    # remove all authentication keys from the current user
    #
    #Examples:
    #
    # $ heroku keys:clear
    # Removing all SSH keys... done
    #
    def clear
      validate_arguments!

      action("Removing all SSH keys") do
        api.delete_keys
      end
    end

    protected
      def format_key_for_display(key)
        type, hex, local = key.strip.split(/\s/)
        [type, hex[0,10] + '...' + hex[-10,10], local].join(' ')
      end
  end
end
