require "heroku/command/base"

# manage app releases
#
class Heroku::Command::Releases < Heroku::Command::Base

  # releases
  #
  # list releases
  #
  #Example:
  #
  # $ heroku releases
  # === example Releases
  # v1 Config add FOO_BAR by email@example.com 0s ago
  # v2 Config add BAR_BAZ by email@example.com 0s ago
  # v3 Config add BAZ_QUX by email@example.com 0s ago
  #
  def index
    validate_arguments!

    releases_data = api.get_releases(app).body.sort_by do |release|
      release["name"][1..-1].to_i
    end.reverse.slice(0, 15)

    unless releases_data.empty?
      releases = releases_data.map do |release|
        [
          release["name"],
          truncate(release["descr"], 40),
          release["user"],
          time_ago(release['created_at'])
        ]
      end

      styled_header("#{app} Releases")
      styled_array(releases, :sort => false)
    else
      display("#{app} has no releases.")
    end
  end

  # releases:info RELEASE
  #
  # view detailed information for a release
  # find latest release details by passing 'current' as the release
  #
  # -s, --shell  # output config vars in shell format
  #
  #Example:
  #
  # $ heroku releases:info v10
  # === Release v10
  # Addons: deployhooks:http
  # By:     email@example.com
  # Change: deploy ABCDEFG
  # When:   2012-01-01 12:00:00
  #
  # === v10 Config Vars
  # EXAMPLE: foo
  #
  def info
    unless release = shift_argument
      error("Usage: heroku releases:info RELEASE")
    end
    validate_arguments!

    release_data = api.get_release(app, release).body

    data = {
      'By'     => release_data['user'],
      'Change' => release_data['descr'],
      'When'   => time_ago(release_data["created_at"])
    }

    unless release_data['addons'].empty?
      data['Addons'] = release_data['addons']
    end

    styled_header("Release #{release}")
    styled_hash(data)

    display

    styled_header("#{release} Config Vars")
    unless release_data['env'].empty?
      if options[:shell]
        release_data['env'].keys.sort.each do |key|
          display("#{key}=#{release_data['env'][key]}")
        end
      else
        styled_hash(release_data['env'])
      end
    else
      display("#{release} has no config vars.")
    end
  end

  # releases:rollback [RELEASE]
  #
  # roll back to an older release
  #
  # if RELEASE is not specified, will roll back one step
  #
  #Example:
  #
  # $ heroku releases:rollback
  # Rolling back example... done, v122
  #
  # $ heroku releases:rollback v42
  # Rolling back example to v42... done
  #
  def rollback
    release = shift_argument
    validate_arguments!

    action("Rolling back #{app}") do
      status(api.post_release(app, release).body)
    end
  end

  alias_command "rollback", "releases:rollback"

end
