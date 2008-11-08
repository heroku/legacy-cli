module Heroku::Command
	class Bundles < Base
		def list
			app_name = extract_app
			list = heroku.bundles(app_name)
			if list.size > 0
				list.each do |bundle|
					space  = ' ' * [(18 - bundle[:name].size),0].max
					display "#{bundle[:name]}" + space + "#{bundle[:state]} #{bundle[:created_at].strftime("%m/%d/%Y %H:%M")}"
				end
			else
				display "#{app_name} has no bundles."
			end
		end
		alias :index :list

		def capture
			app_name = extract_app
			bundle = args.shift.strip.downcase rescue nil

			bundle = heroku.bundle_capture(app_name, bundle)
			display "Began capturing bundle #{bundle} from #{app_name}"
		end

		def destroy
			app_name = extract_app
			bundle = args.first.strip.downcase rescue nil
			unless bundle
				display "Usage: heroku bundle:destroy <bundle>"
			else
				heroku.bundle_destroy(app_name, bundle)
				display "Destroyed bundle #{bundle} from #{app_name}"
			end
		end

		def download
			app_name = extract_app
			fname = "#{app_name}.tar.gz"
			bundle = args.shift.strip.downcase rescue nil
			heroku.bundle_download(app_name, fname, bundle)
			display "Downloaded #{File.stat(fname).size} byte bundle #{fname}"
		end

		def animate
			app_name = extract_app
			bundle = args.shift.strip.downcase rescue ""
			if bundle.length == 0
				display "Usage: heroku bundle:animate <bundle>"
			else
				name = heroku.create(nil, :origin_bundle_app => app_name, :origin_bundle => bundle)
				display "Animated #{app_name} #{bundle} into #{app_urls(name)}"
			end
		end
	 end
end