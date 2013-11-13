require "heroku/command/base"
require "heroku/client/organizations"
require "base64"
require "excon"

# manage organization accounts
#
class Heroku::Command::Orgs < Heroku::Command::Base

  # orgs
  #
  # lists the orgs that you are a member of.
  #
  #
  def index
    response = Heroku::Client::Organizations.get_orgs

    orgs = []
    response.fetch('organizations', []).each do |org|
      orgs << org
      org.fetch('child_orgs', []).each do |child|
        orgs << child
      end
    end

    default = response['user']['default_organization'] || ""

    orgs.map! do |org|
      name = org["organization_name"]
      t = []
      t <<  org["role"]
      t << 'default' if name == default
      [name, t.join(', ')]
    end

    if orgs.empty?
      display("You are not a member of any organizations.")
    else
      styled_array(orgs)
    end
  end

  # orgs:open ORG
  #
  # opens the org interface in a browser
  #
  #
  def open
    launchy("Opening web interface for #{org}", "https://dashboard.heroku.com/orgs/#{org}/apps")
  end

  def self.add_headers(headers)
    Heroku::Client::Organizations.headers = headers
  end

end
