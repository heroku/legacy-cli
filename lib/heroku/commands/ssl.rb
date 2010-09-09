module Heroku::Command
  class Ssl < BaseWithApp
    def list
      heroku.list_domains(app).each do |d|
        if cert = d[:cert]
          display "#{d[:domain]} has a SSL certificate registered to #{cert[:subject]} which expires on #{cert[:expires_at].strftime("%b %d, %Y")}"
        else
          display "#{d[:domain]} has no certificate"
        end
      end
    end
    alias :index :list

    def add
      usage  = 'heroku ssl:add <pem> <key>'
      raise CommandFailed, "Missing pem file. Usage:\n#{usage}" unless pem_file = args.shift
      raise CommandFailed, "Missing key file. Usage:\n#{usage}" unless key_file = args.shift
      raise CommandFailed, "Could not find pem in #{pem_file}"  unless File.exists?(pem_file)
      raise CommandFailed, "Could not find key in #{key_file}"  unless File.exists?(key_file)

      pem  = File.read(pem_file)
      key  = File.read(key_file)
      info = heroku.add_ssl(app, pem, key)
      display "Added certificate to #{info['domain']}, expiring in #{info['expires_at']}"
    end

    def remove
      raise CommandFailed, "Missing domain. Usage:\nheroku ssl:remove <domain>" unless domain = args.shift
      heroku.remove_ssl(app, domain)
      display "Removed certificate from #{domain}"
    end

    def clear
      heroku.clear_ssl(app)
      display "Cleared certificates for #{app}"
    end
  end
end