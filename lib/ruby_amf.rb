require 'active_record'

$:.unshift(File.expand_path('../../ext', __FILE__))
$:.unshift File.dirname(__FILE__)

# core, must be loaded in this order

require 'ruby_amf/typed_hash'
require 'ruby_amf/messages'
require 'ruby_amf/class_mapping'
require 'ruby_amf/remoting'
require 'ruby_amf/gateway'
require 'ruby_amf/logger'
require 'ruby_amf/action_controller'

# load pure extension, overrides serialization 
# methods in RubyAMF::Remoting::Envelope
# require 'ruby_amf/pure'

# or

# native C IO extension, overrides serialization
# methods in RubyAMF::Remoting::Envelope
require 'ruby_amf_ext'
