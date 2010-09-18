$:.unshift File.dirname(__FILE__)

require 'pure/constants'
require 'pure/binary_helpers'
require 'pure/deserializer'
require 'pure/serializer'
require 'pure/remoting'

module RubyAMF
  module Pure

    def self.deserialize source, amf_version = 0
      if amf_version == 0
        Pure::AMF0Deserializer.new.deserialize(source)
      elsif amf_version == 3
        Pure::AMF3Deserializer.new.deserialize(source)
      else
        raise Exception.new("unsupported version #{amf_version}")
      end
    end

    def self.serialize obj, amf_version = 0
      if amf_version == 0
        Pure::AMF0Serializer.new.serialize(obj)
      elsif amf_version == 3
        Pure::AMF3Serializer.new.serialize(obj)
      else
        raise Exception.new("unsupported version #{amf_version}")
      end
    end
  end
end