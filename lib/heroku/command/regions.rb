require "heroku/command/base"

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
  # === Regions
  # us
  # eu
  def index
    regions = json_decode(heroku.get("/regions"))
    styled_header("Regions")
    styled_array(regions.map { |region| [region["slug"], region["name"]] })
  end
end

