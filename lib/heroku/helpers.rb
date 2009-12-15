module Heroku
	module Helpers
		def home_directory
			running_on_windows? ? ENV['USERPROFILE'] : ENV['HOME']
		end

		def running_on_windows?
			RUBY_PLATFORM =~ /mswin32|mingw32/
		end

		def running_on_a_mac?
			RUBY_PLATFORM =~ /-darwin\d/
		end
	end
end

unless String.method_defined?(:shellescape)
	class String
		def shellescape
			empty? ? "''" : gsub(/([^A-Za-z0-9_\-.,:\/@\n])/n, '\\\\\\1').gsub(/\n/, "'\n'")
		end
	end
end
