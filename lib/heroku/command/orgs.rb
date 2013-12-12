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

  # orgs:open --org ORG
  #
  # opens the org interface in a browser
  #
  #
  def open
    launchy("Opening web interface for #{org}", "https://dashboard.heroku.com/orgs/#{org}/apps")
  end

  # orgs:default [TARGET]
  #
  # sets the default org.
  # TARGET can be an org you belong to or it can be "personal"
  # for your personal account. If no argument or option is given,
  # the default org is displayed
  #
  #
  def default
    options[:ignore_no_org] = true
    if target = shift_argument
      options[:org] = target
    end

    if org == "personal" || options[:personal]
      action("Setting personal account as default") do
        org_api.remove_default_org
      end
    elsif org && !options[:using_default_org]
      action("Setting #{org} as the default organization") do
        org_api.set_default_org(org)
      end
    elsif org
      display("#{org} is the default organization.")
    else
      display("Personal account is default.")
    end
  end

end
