require "heroku/client"

class Heroku::Client::HerokuPostgresql
  Version = 11

  include Heroku::Helpers

  @headers = { :x_heroku_gem_version  => Heroku::Client.version }

  def self.add_headers(headers)
    @headers.merge! headers
  end

  def self.headers
    @headers
  end

  attr_reader :attachment
  def initialize(attachment)
    @attachment = attachment
  end

  def heroku_postgresql_host
    if attachment.starter_plan?
      determine_host(ENV["HEROKU_POSTGRESQL_HOST"], "postgres-starter-api.heroku.com")
    else
      if ENV['SHOGUN']
        "shogun-#{ENV['SHOGUN']}.herokuapp.com"
      else
        determine_host(ENV["HEROKU_POSTGRESQL_HOST"], "postgres-api.heroku.com")
      end
    end
  end

  def resource_name
    attachment.resource_name
  end

  def heroku_postgresql_resource
    RestClient::Resource.new(
      "https://#{heroku_postgresql_host}/client/v11/databases",
      :user => Heroku::Auth.user,
      :password => Heroku::Auth.password,
      :headers => self.class.headers
      )
  end

  def ingress
    http_put "#{resource_name}/ingress"
  end

  def metrics
    http_get "#{resource_name}/metrics"
  end

  def reset
    http_put "#{resource_name}/reset"
  end

  def connection_reset
    http_post "#{resource_name}/connection_reset"
  end

  def rotate_credentials
    http_post "#{resource_name}/credentials_rotation"
  end

  def get_database(extended=false)
    query = extended ? '?extended=true' : ''
    http_get resource_name + query
  end

  def get_wait_status
    http_get "#{resource_name}/wait_status"
  end

  def unfollow
    http_put "#{resource_name}/unfollow"
  end

  def upgrade
    http_post "#{resource_name}/upgrade"
  end

  def upgrade_status
    http_get "#{resource_name}/upgrade_status"
  end

  def maintenance_info
    http_get "#{resource_name}/maintenance"
  end

  def maintenance_run
    http_post "#{resource_name}/maintenance"
  end

  def maintenance_window_set(description)
    http_put "#{resource_name}/maintenance_window", 'description' => description
  end

  # backups
  def backups
    http_get "#{resource_name}/transfers"
  end

  def backups_get(id, verbose=false)
    http_get "#{resource_name}/transfers/#{URI.encode(id)}?verbose=#{verbose}"
  end

  def backups_capture
    http_post "#{resource_name}/backups"
  end

  def backups_restore(backup_url)
    http_post "#{resource_name}/restores", 'backup_url' => backup_url
  end

  def backups_delete(id)
    http_delete "#{resource_name}/backups/#{URI.encode(id)}"
  end

  def pg_copy(source_name, source_url, target_name, target_url)
    http_post "#{resource_name}/transfers", {
      'from_name' => source_name,
      'from_url' => source_url,
      'to_name' => target_name,
      'to_url' => target_url,
    }
  end

  def schedules
    http_get "#{resource_name}/transfer-schedules"
  end

  def schedule(opts={})
    http_post "#{resource_name}/transfer-schedules", opts
  end

  def unschedule(id)
    http_delete "#{resource_name}/transfer-schedules/#{URI.encode(id.to_s)}"
  end

  protected

  def sym_keys(c)
    if c.is_a?(Array)
      c.map { |e| sym_keys(e) }
    else
      c.inject({}) do |h, (k, v)|
        h[k.to_sym] = v; h
      end
    end
  end

  def checking_client_version
    begin
      yield
    rescue RestClient::BadRequest => e
      if message = json_decode(e.response.to_s)["upgrade_message"]
        abort(message)
      else
        raise e
      end
    end
  end

  def display_heroku_warning(response)
    warning = response.headers[:x_heroku_warning]
    display warning if warning
    response
  end

  def http_get(path)
    checking_client_version do
      retry_on_exception(RestClient::Exception) do
        response = heroku_postgresql_resource[path].get
        display_heroku_warning response
        sym_keys(json_decode(response.to_s))
      end
    end
  end

  def http_post(path, payload = {})
    checking_client_version do
      response = heroku_postgresql_resource[path].post(json_encode(payload))
      display_heroku_warning response
      sym_keys(json_decode(response.to_s))
    end
  end

  def http_put(path, payload = {})
    checking_client_version do
      response = heroku_postgresql_resource[path].put(json_encode(payload))
      display_heroku_warning response
      sym_keys(json_decode(response.to_s))
    end
  end

  def http_delete(path)
    checking_client_version do
      response = heroku_postgresql_resource[path].delete
      display_heroku_warning response
      sym_keys(json_decode(response.to_s))
    end
  end

  private

  def determine_host(value, default)
    if value.nil?
      default
    else
      "#{value}.herokuapp.com"
    end
  end
end

module HerokuPostgresql
  class Client < Heroku::Client::HerokuPostgresql
    def initialize(*args)
      Heroku::Helpers.deprecate "HerokuPostgresql::Client has been deprecated. Please use Heroku::Client::HerokuPostgresql instead."
      super
    end
  end
end
