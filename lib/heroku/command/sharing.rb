require "heroku/command/base"

module Heroku::Command

  # manage collaborators on an app
  #
  class Sharing < Base

    # sharing
    #
    # list collaborators on an app
    #
    def index
      collaborators = heroku.list_collaborators(app)
      if collaborators.empty?
        display("#{app} has no collaborators")
      else
        display(collaborators.map { |c| c[:email] }.join("\n"))
      end
    end

    # sharing:add EMAIL
    #
    # add a collaborator to an app
    #
    def add
      email = args.shift.downcase rescue ''
      raise(CommandFailed, "Specify an email address to share the app with.") if email == ''
      heroku.add_collaborator(app, email)
      display "#{email} added to #{app} collaborators"
    end

    # sharing:remove EMAIL
    #
    # remove a collaborator from an app
    #
    def remove
      email = args.shift.downcase rescue ''
      raise(CommandFailed, "Specify an email address to remove from the app.") if email == ''
      heroku.remove_collaborator(app, email)
      display "#{email} removed from #{app} collaborators"
    end

    # sharing:transfer EMAIL
    #
    # transfer an app to a new owner
    #
    def transfer
      email = args.shift.downcase rescue ''
      raise(CommandFailed, "Specify the email address of the new owner") if email == ''
      heroku.update(app, :transfer_owner => email)
      display "#{app} ownership transfered. New owner is #{email}"
    end
  end
end
