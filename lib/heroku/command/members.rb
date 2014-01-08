require "heroku/command/base"
require "base64"
require "excon"

# manage membership in organization accounts
#
class Heroku::Command::Members < Heroku::Command::Base

  # members [--org ORG]
  #
  # lists members in an org
  #
  # -r, --role ROLE  # list only members in ROLE
  #
  #
  def index
    resp = org_api.get_members(org).body
    resp = resp.select { |m| m['role'] == options[:role] } if options[:role]
    list = resp.map { |m| [m['email'] , m['role']] }

    styled_header("Members of organization #{org}")
    styled_array(list)
  rescue Excon::Errors::NotFound, Excon::Errors::Unauthorized, Excon::Errors::Forbidden
    error("You do not have access to organization #{org} or it doesn't exist")
  end

  # members:add EMAIL [--org ORG] [--role ROLE]
  #
  # adds a new member to an org
  #
  # -r, --role ROLE  # role for this member. One of 'admin' or 'member'
  #                  # Default is 'member'
  def add
    unless member = shift_argument
      error("Usage: heroku members:add EMAIL\nMust specify EMAIL to add.")
    end

    role = options.fetch(:role, 'member')

    action("Adding #{member} as #{role} to organization #{org}") do
      response = org_api.add_member(org, member, role)
      if response.status == 302
        org_api.set_member(org, member, role)
      end
    end
  end

  # members:set NAME [--org ORG] [--role ROLE]
  #
  # change role of member in org
  #
  # -r, --role ROLE  # the new role for this member. One of 'admin' or 'member'
  #
  #
  def set
    unless member = shift_argument
      error("Usage: heroku members:set EMAIL\nMust specify EMAIL to update.")
    end

    role = options[:role] || 'member'
    unless %w(admin member).include?(role)
      error("Invalid role. Must be one of 'admin' or 'member'")
    end

    action("Setting role of #{member} in organization #{org} to #{role}") do
      org_api.set_member(org, member, role)
    end
  end

  # members:remove EMAIL [--org ORG]
  #
  # removes a member from an org
  #
  #
  def remove
    unless member = shift_argument
      error("Usage: heroku members:remove EMAIL\nMust specify EMAIL to remove.")
    end

    action("Removing #{member} from organization #{org}") do
      org_api.remove_member(org, member)
    end
  end

end
