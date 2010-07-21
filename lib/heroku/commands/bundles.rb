module Heroku::Command
  class Bundles < BaseWithApp
    def list
      list = heroku.bundles(app)
      if list.size > 0
        list.each do |bundle|
          space  = ' ' * [(18 - bundle[:name].size),1].max
          display "#{bundle[:name]}" + space + "#{bundle[:state]} #{bundle[:created_at].strftime("%m/%d/%Y %H:%M")}"
        end
      else
        display "#{app} has no bundles."
      end
    end
    alias :index :list

    def capture
      bundle = args.shift.strip.downcase rescue nil

      bundle = heroku.bundle_capture(app, bundle)
      display "Began capturing bundle #{bundle} from #{app}"
    end

    def destroy
      bundle = args.first.strip.downcase rescue nil
      unless bundle
        display "Usage: heroku bundle:destroy <bundle>"
      else
        heroku.bundle_destroy(app, bundle)
        display "Destroyed bundle #{bundle} from #{app}"
      end
    end

    def download
      fname = "#{app}.tar.gz"
      bundle = args.shift.strip.downcase rescue nil
      url = heroku.bundle_url(app, bundle)
      File.open(fname, "wb") { |f| f.write RestClient.get(url).to_s }
      display "Downloaded #{File.stat(fname).size} byte bundle #{fname}"
    end
  end
end
