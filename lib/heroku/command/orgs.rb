require "heroku/command/base"
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
    response = org_api.get_orgs.body

    orgs = []
    response.fetch('organizations', []).each do |org|
      orgs << org
      org.fetch('child_orgs', []).each do |child|
        orgs << child
      end
    end

    orgs.map! do |org|
      name = org["organization_name"]
      t = []
      t <<  org["role"]
      [name, t.join(', ')]
    end

    if orgs.empty?
      display("You are not a member of any organizations.")
    else
      styled_array(orgs)
    end
  end

  # orgs:open --org ORG
  #
  # opens the org interface in a browser
  #
  #
  def open
    launchy("Opening web interface for #{org}", "https://dashboard.heroku.com/orgs/#{org}/apps")
  end

  # orgs:default
  #
  # DEPRECATED: Use HEROKU_ORGANIZATION environment variable
  #
  def default
    display("DEPRECATED: Use HEROKU_ORGANIZATION environment variable.")
  end

end
