require 'rubygems'
require 'spec'
require 'fileutils'

require File.dirname(__FILE__) + '/../lib/heroku'
require 'command_line'

class Module
	def redefine_const(name, value)
		__send__(:remove_const, name) if const_defined?(name)
		const_set(name, value)
	end
end