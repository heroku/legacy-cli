module Heroku::Git
  extend Heroku::Helpers

  def self.check_git_version
    return unless running_on_windows? || running_on_a_mac?
    v = Version.parse(git_version)
    if v > Version.parse('1.8') && v < Version.parse('1.8.5.6')
      warn_about_insecure_git
    end
    if v > Version.parse('1.9') && v < Version.parse('1.9.5')
      warn_about_insecure_git
    end
    if v > Version.parse('2.0') && v < Version.parse('2.0.5')
      warn_about_insecure_git
    end
    if v > Version.parse('2.1') && v < Version.parse('2.2.1')
      warn_about_insecure_git
    end
  end

  def self.warn_about_insecure_git
    warn "Your version of git is #{git_version}. Which has serious security vulnerabilities."
    warn "More information here: https://blog.heroku.com/archives/2014/12/23/update_your_git_clients_on_windows_and_os_x"
  end

  private

  def self.git_version
    /git version ([\d\.]+)/.match(`git --version`)[1]
  end


  class Version
    include Comparable

    attr_accessor :major, :minor, :patch, :special

    def initialize(major, minor=0, patch=0, special=0)
      @major, @minor, @patch, @special = major, minor, patch, special
    end

    def self.parse(s)
      digits = s.split('.').map { |i| i.to_i }
      Version.new(*digits)
    end

    def <=>(other)
      return major <=> other.major unless (major <=> other.major) == 0
      return minor <=> other.minor unless (minor <=> other.minor) == 0
      return patch <=> other.patch unless (patch <=> other.patch) == 0
      return special <=> other.special
    end
  end
end
