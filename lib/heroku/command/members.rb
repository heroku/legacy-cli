require "heroku/command/base"
require "heroku/client/organizations"
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
    resp = Heroku::Client::Organizations.get_members(org)
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
      Heroku::Client::Organizations.add_member(org, member, role)
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
      Heroku::Client::Organizations.remove_member(org, member)
    end
  end

end
