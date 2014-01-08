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
    # === example Collaborators
    # collaborator@example.com  collaborator
    # email@example.com         owner
    #
    def index
      validate_arguments!

      # this is never empty, as it always includes the owner
      collaborators = api.get_collaborators(app).body
      collaborators = collaborators.delete_if { |collaborator| org? collaborator["email"] }

      styled_header("#{app} Access List")
      styled_array(collaborators.map {|collaborator| [collaborator["email"], collaborator.fetch("role", "collaborator")] })
    end

    # sharing:add EMAIL
    #
    # add a collaborator to an app
    #
    #Example:
    #
    # $ heroku sharing:add collaborator@example.com
    # Adding collaborator@example.com to example collaborators... done
    #
    def add
      unless email = shift_argument
        error("Usage: heroku sharing:add EMAIL\nMust specify EMAIL to add sharing.")
      end
      validate_arguments!
      org_from_app!

      action("Adding #{email} to #{app} as collaborator") do
        if org && org_api.get_members(org).body.map { |m| m['email'] }.include?(email)
          org_api.post_collaborator(org, app, email)
        else
          api.post_collaborator(app, email)
        end
      end
    end

    # sharing:remove EMAIL
    #
    # remove a collaborator from an app
    #
    #Example:
    #
    # $ heroku sharing:remove collaborator@example.com
    # Removing collaborator@example.com to example collaborators... done
    #
    def remove
      unless email = shift_argument
        error("Usage: heroku sharing:remove EMAIL\nMust specify EMAIL to remove sharing.")
      end
      validate_arguments!
      org_from_app!

      action("Removing #{email} from #{app} collaborators") do
        if org && org_api.get_members(org).body.map { |m| m['email'] }.include?(email)
          org_api.delete_collaborator(org, app, email)
        else
          api.delete_collaborator(app, email)
        end
      end
    end

    # sharing:transfer TARGET
    #
    # transfers an app to another user or an organization.
    # TARGET is the email of another user or the name of the
    # organization to transfer to.
    #
    #Example:
    #
    # $ heroku sharing:transfer collaborator@example.com
    # Transferring example to collaborator@example.com... done
    #
    # $ heroku sharing:transfer acme-widgets
    # Transferring example to acme-widgets... done
    #
    # -l, --locked   # lock the app upon transfer
    #
    def transfer
      unless target = shift_argument
        error("Usage: heroku sharing:transfer EMAIL\nMust specify EMAIL to transfer an app.")
      end
      validate_arguments!
      org_from_app!

      action("Transferring #{app} to #{target}") do
        if org || !target.include?('@')
          locked = options[:locked]

          org_api.transfer_app(target, app, locked)
          display("App is locked. Organization members must be invited to access.") if locked

        else
          api.put_app(app, "transfer_owner" => target)
        end
      end
    end
  end
end
