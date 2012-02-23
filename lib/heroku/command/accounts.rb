if Heroku::Plugin.list.include?('heroku-accounts')
  # manage multiple heroku accounts
  #
  class Heroku::Command::Accounts < Heroku::Command::Base

    # accounts:default
    # set a system-wide default account
    def default
      name = args.shift

      error("Please specify an account name.") unless name
      error("That account does not exist.") unless account_exists?(name)

      result = %x{ git config --global heroku.account #{name} }

      # update netrc
      Heroku::Auth.instance_variable_set(:@account, nil) # kill memoization
      Heroku::Auth.credentials = [Heroku::Auth.user, Heroku::Auth.password]
      Heroku::Auth.write_credentials

      result
    end

  end
end
