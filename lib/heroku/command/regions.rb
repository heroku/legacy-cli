require "heroku/command/base"

# HIDDEN: get info on available regions
#
class Heroku::Command::Regions < Heroku::Command::Base

  # regions
  #
  # HIDDEN: List available regions for deployment
  #
  #Example:
  #
  # $ heroku regions
  # === Regions
  # us
  def index
    regions = json_decode(heroku.get("/regions"))
    styled_header("Regions")
    styled_array(regions.map { |region| [region["slug"], region["name"]] })
  end
end

