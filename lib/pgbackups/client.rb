module PGBackups
  class Client
    def initialize(uri)
      @uri = URI.parse(uri)
    end

    def check_client_version
      heroku_postgresql_host = ENV["HEROKU_POSTGRESQL_HOST"] || "https://shogun.heroku.com"
      begin
        RestClient::Resource.new(
          "#{heroku_postgresql_host}/client/version",
          :headers => {:heroku_client_version => HerokuPostgresql::Client::Version}
        ).get
      rescue RestClient::BadRequest => e
        if message = JSON.parse(e.response.to_s)["upgrade_message"]
          abort(message)
        else
          raise e
        end
      end
    end

    def authenticated_resource(path)
      check_client_version
      host = "#{@uri.scheme}://#{@uri.host}"
      host += ":#{@uri.port}" if @uri.port
      RestClient::Resource.new("#{host}#{path}",
        :user     => @uri.user,
        :password => @uri.password,
        :headers  => {:heroku_client_version => HerokuPostgresql::Client::Version}
      )
    end

    def create_transfer(from_url, from_name, to_url, to_name, opts={})
      # opts[:expire] => true will delete the oldest backup if at the plan limit
      resource = authenticated_resource("/client/transfers")
      params = {:from_url => from_url, :from_name => from_name, :to_url => to_url, :to_name => to_name}.merge opts
      JSON.parse resource.post(params).body
    end

    def get_transfers
      resource = authenticated_resource("/client/transfers")
      JSON.parse resource.get.body
    end

    def get_transfer(id)
      resource = authenticated_resource("/client/transfers/#{id}")
      JSON.parse resource.get.body
    end

    def get_backups(opts={})
      resource = authenticated_resource("/client/backups")
      JSON.parse resource.get.body
    end

    def get_backup(name, opts={})
      name = URI.escape(name)
      resource = authenticated_resource("/client/backups/#{name}")
      JSON.parse resource.get.body
    end

    def get_latest_backup
      resource = authenticated_resource("/client/latest_backup")
      JSON.parse resource.get.body
    end

    def delete_backup(name)
      name = URI.escape(name)
      begin
        resource = authenticated_resource("/client/backups/#{name}")
        resource.delete.body
        true
      rescue RestClient::ResourceNotFound => e
        false
      end
    end
  end
end