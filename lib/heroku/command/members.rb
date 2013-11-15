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
  # -o, --org ORG    # the org to list the apps for.
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

end
