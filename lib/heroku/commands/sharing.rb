module Heroku::Command
  class Sharing < BaseWithApp
    def list
      list = heroku.list_collaborators(app)
      display list.map { |c| c[:email] }.join("\n")
    end
    alias :index :list

    def add
      email = args.shift.downcase rescue ''
      raise(CommandFailed, "Specify an email address to share the app with.") if email == ''
      display heroku.add_collaborator(app, email)
    end

    def remove
      email = args.shift.downcase rescue ''
      raise(CommandFailed, "Specify an email address to remove from the app.") if email == ''
      heroku.remove_collaborator(app, email)
      display "Collaborator removed."
    end

    def transfer
      email = args.shift.downcase rescue ''
      raise(CommandFailed, "Specify the email address of the new owner") if email == ''
      heroku.update(app, :transfer_owner => email)
      display "App ownership transfered. New owner is #{email}"
    end
  end
end
