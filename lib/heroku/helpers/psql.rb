module Helpers
  class PSQL
    attr_reader :attachment

    def initialize(attachment)
      @attachment = attachment
      if @attachment.kind_of? Array
        @uri = URI.parse(attachment.last)
      else
        @uri = URI.parse(attachment.url)
      end
      ENV["PGPASSWORD"] = @uri.password
      ENV["PGSSLMODE"]  = (@uri.host == 'localhost' ?  'prefer' : 'require' )
    end

    def exec_sql(sql)
      user_part = @uri.user ? "-U #{@uri.user}" : ""
      output = `#{psql_cmd} -c "#{sql}" #{user_part} -h #{@uri.host} -p #{@uri.port || 5432} #{@uri.path[1..-1]}`
      case status_code
      when 0
        output
      when 32512
        raise "The local psql command could not be located"
        abort
      else
        raise "psql failed. exit status #{status_code}, output: #{output.inspect}"
      end
    end

    def shell(command)
      prompt_expr = "#{@attachment.app}::#{@attachment.name.sub(/^HEROKU_POSTGRESQL_/,'').gsub(/\W+/, '-')}%R%#"
      prompt_flags = %Q(--set "PROMPT1=#{prompt_expr}" --set "PROMPT2=#{prompt_expr}")
      if command
        command = %Q(-c "#{command}")
      end
      exec "psql -U #{@uri.user} -h #{@uri.host} -p #{@uri.port || 5432} #{prompt_flags} #{command} #{@uri.path[1..-1]}"
    end

    private

    def psql_cmd
      # some people alais psql, so we need to find the real psql
      # but windows doesn't have the command command
      Heroku::Helpers.running_on_windows? ? 'psql' : 'command psql'
    end

    def status_code
      $?.to_i
    end
  end

  class PSQLException < Exception
  end
end
