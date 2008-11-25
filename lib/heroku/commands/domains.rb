module Heroku::Command
	class Domains < Base
		def list
			name = extract_app
			domains = heroku.list_domains(name)
			if domains.empty?
				display "No domain names for #{name}.#{heroku.host}"
			else
				display "Domain names for #{name}.#{heroku.host}:"
				display domains.join("\n")
			end
		end
		alias :index :list

		def add
			name = extract_app
			domain = args.shift.downcase rescue nil
			heroku.add_domain(name, domain)
			display "Added #{domain} as a custom domain name to #{name}.#{heroku.host}"
		end

		def remove
			name = extract_app
			domain = args.shift.downcase rescue nil
			heroku.remove_domain(name, domain)
			display "Removed #{domain} as a custom domain name to #{name}.#{heroku.host}"
		end

		def clear
			name = extract_app
			heroku.remove_domains(name)
			display "Removed all domain names for #{name}.#{heroku.host}"
		end
	end
end