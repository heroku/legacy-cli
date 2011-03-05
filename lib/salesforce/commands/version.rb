module Salesforce::Command
  class Version < Base
    def index
      display Salesforce::Client.gem_version_string
    end
  end
end
