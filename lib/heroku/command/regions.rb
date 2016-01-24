require "heroku/command/base"
require "heroku/api/regions_v3"

# list available regions
#
class Heroku::Command::Regions < Heroku::Command::Base

  # regions
  #
  # List available regions for deployment
  #
  #Example:
  #
  # $ heroku regions
  # === Common Runtime
  # eu         Europe
  # us         United States
  #
  # === Private Spaces
  # frankfurt  Frankfurt, Germany
  # oregon     Oregon, United States
  # tokyo      Tokyo, Japan
  # virginia   Virginia, United States
  def index
    ps, cr = api.get_regions_v3.body.partition { |r| r["private_capable"] }
    styled_regions("Common Runtime", cr)
    styled_regions("Private Spaces", ps)
  end

  private

  def styled_regions(title, regions)
    styled_header(title)
    styled_array(regions.map { |r| [r["name"], r["description"]] })
  end
end

