$:.unshift(File.expand_path('../../ext', __FILE__))
$:.unshift File.dirname(__FILE__)

# core, must be loaded in this order
require 'ruby_amf/typed_hash'
require 'ruby_amf/messages'
require 'ruby_amf/remoting'
require 'ruby_amf/class_mapping'
require 'ruby_amf/gateway'

# native C IO extension
require 'ruby_amf_ext'

# helpers for errors and rendering
require 'ruby_amf/lib/action_controller'
