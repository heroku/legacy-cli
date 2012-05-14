require "heroku/command/base"

module Heroku::Command

  # manage collaborators on an app
  #
  class Sharing < Base

    # sharing
    #
    # list collaborators on an app
    #
    #Example:
    #
    # $ heroku sharing
    # === myapp Collaborators
    # collaborator@example.com
    # email@example.com
    #
    def index
      validate_arguments!

      collaborators = api.get_collaborators(app).body
      unless collaborators.empty?
        styled_header("#{app} Collaborators")
        styled_array(collaborators.map {|collaborator| collaborator["email"]})
      else
        display("#{app} has no collaborators")
      end
    end

    # sharing:add EMAIL
    #
    # add a collaborator to an app
    #
    #Example:
    #
    # $ heroku sharing:add collaborator@example.com
    # Adding collaborator@example.com to myapp collaborators... done
    #
    def add
      unless email = shift_argument
        raise(CommandFailed, "Specify an email address to share the app with.")
      end
      validate_arguments!

      action("Adding #{email} to #{app} collaborators") do
        api.post_collaborator(app, email)
      end
    end

    # sharing:remove EMAIL
    #
    # remove a collaborator from an app
    #
    #Example:
    #
    # $ heroku sharing:remove collaborator@example.com
    # Removing collaborator@example.com to myapp collaborators... done
    #
    def remove
      unless email = shift_argument
        raise(CommandFailed, "Specify an email address to remove from the app.")
      end
      validate_arguments!

      action("Removing #{email} from #{app} collaborators") do
        api.delete_collaborator(app, email)
      end
    end

    # sharing:transfer EMAIL
    #
    # transfer an app to a new owner
    #
    #Example:
    #
    # $ heroku sharing:transfer collaborator@example.com
    # Transferring myapp to collaborator@example.com... done
    #
    def transfer
      unless email = shift_argument
        raise(CommandFailed, "Specify the email address of the new owner")
      end
      validate_arguments!

      action("Transferring #{app} to #{email}") do
        api.put_app(app, "transfer_owner" => email)
      end
    end
  end
end
