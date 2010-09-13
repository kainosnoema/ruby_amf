require 'ruby_amf/remoting'

module RubyAMF
  module Remoting
    class Envelope

      def deserialize stream
        stream = StringIO.new(stream) unless stream.is_a?(StringIO)

        # Initialize
        @amf_version = 0
        @headers = []
        @bodies = []

        # Read AMF version
        @amf_version = read_word16_network stream

        # Read in headers
        header_count = read_word16_network stream
        0.upto(header_count-1) do
          name = stream.read(read_word16_network(stream))
          name.force_encoding("UTF-8") if name.respond_to?(:force_encoding)

          must_understand = read_int8(stream) != 0
          length = read_word32_network stream
          data = RubyAMF::Pure.deserialize(stream)

          @headers << RubyAMF::Remoting::Envelope::Header.new(name, must_understand, data)
        end

        # Read in messages
        message_count = read_word16_network stream
        0.upto(message_count-1) do
          target_uri = stream.read(read_word16_network(stream))
          target_uri.force_encoding("UTF-8") if target_uri.respond_to?(:force_encoding)

          response_uri = stream.read(read_word16_network(stream))
          response_uri.force_encoding("UTF-8") if response_uri.respond_to?(:force_encoding)

          length = read_word32_network stream
          data = RubyAMF::Pure.deserialize(stream)

          @bodies << RubyAMF::Remoting::Envelope::Body.new(target_uri, response_uri, data)
        end

        self
      end

      def serialize
        stream = ""

        # Write version
        stream << pack_int16_network(@amf_version)

        # Write headers
        stream << pack_int16_network(@headers.length) # Header count
        @headers.each do |h|
          name_str = h.name
          name_str.encode!("UTF-8").force_encoding("ASCII-8BIT") if name_str.respond_to?(:encode)
          stream << pack_int16_network(name_str.bytesize)
          stream << name_str
          stream << pack_int8(h.must_understand ? 1 : 0)
          stream << pack_word32_network(-1)
          stream << RubyAMF::Pure.serialize(h.data, 0)
        end

        # Write messages
        stream << pack_int16_network(@bodies.length) # Message count
        @bodies.each do |m|
          uri_str = m.target_uri
          uri_str.encode!("UTF-8").force_encoding("ASCII-8BIT") if uri_str.respond_to?(:encode)
          stream << pack_int16_network(uri_str.bytesize)
          stream << uri_str

          uri_str = m.response_uri
          uri_str.encode!("UTF-8").force_encoding("ASCII-8BIT") if uri_str.respond_to?(:encode)
          stream << pack_int16_network(uri_str.bytesize)
          stream << uri_str

          stream << pack_word32_network(-1)
          stream << AMF0_AMF3_MARKER if @amf_version == 3
          stream << RubyAMF::Pure.serialize(m.data, @amf_version)
        end

        stream
      end
    
      private
        include RubyAMF::Pure::ReadBinaryHelpers
        include RubyAMF::Pure::WriteBinaryHelpers
    end
  end
end