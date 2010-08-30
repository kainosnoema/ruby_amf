require 'rubygems'
require 'test/unit'

$:.unshift(File.expand_path('..', __FILE__))

require 'active_support/core_ext'
require 'lib/ruby_amf/typed_hash'
require 'lib/ruby_amf/messages'
require 'lib/ruby_amf/remoting'
require 'lib/ruby_amf/class_mapping'
require 'ext/ruby_amf_ext'
require 'fixtures'

class Test::Unit::TestCase
end
