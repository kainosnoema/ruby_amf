module RubyAMF
  module Remoting
    # Container for the AMF request/response.
    class Envelope
      include RubyAMF::Ext::AMF3Deserializer
      include RubyAMF::Ext::AMF3Serializer
      
      attr_reader :amf_version, :headers, :bodies
      
      @amf_version = 0
      @headers = []
      @bodies = []

      def initialize(stream = nil)
        deserialize(stream) if stream # calls native C extension
      end
      
      # Builds response from the request, iterating over each method call and using
      # the return value as the method call's return value
      # def each_method_call request, &block
      #   raise 'Response already constructed' if @constructed
      # 
      #   # Set version from response
      #   # Can't just copy version because FMS sends version as 1
      #   @amf_version = request.amf_version == 3 ? 3 : 0 
      # 
      #   request.messages.each do |m|
      #     # What's the request body?
      #     case m.data
      #       when Messages::CommandMessage
      #         # Pings should be responded to with an AcknowledgeMessage built using the ping
      #         # Everything else is unsupported
      #         command_msg = m.data
      #         if command_msg.operation == Messages::CommandMessage::CLIENT_PING_OPERATION
      #           response_value = Values::AcknowledgeMessage.new(command_msg)
      #         else
      #           e = Exception.new("CommandMessage #{command_msg.operation} not implemented")
      #           e.set_backtrace ["RocketAMF::Envelope each_method_call"]
      #           response_value = Values::ErrorMessage.new(command_msg, e)
      #         end
      #       when Messages::RemotingMessage
      #         # Using RemoteObject style message calls
      #         remoting_msg = m.data
      #         acknowledge_msg = Values::AcknowledgeMessage.new(remoting_msg)
      #         method_base = remoting_msg.source.to_s.empty? ? '' : remoting_msg.source+'.'
      #         body = dispatch_call :method => method_base+remoting_msg.operation, :args => remoting_msg.body, :source => remoting_msg, :block => block
      # 
      #         # Response should be the bare ErrorMessage if there was an error
      #         if body.is_a?(Messages::ErrorMessage)
      #           response_value = body
      #         else
      #           acknowledge_msg.body = body
      #           response_value = acknowledge_msg
      #         end
      #       else
      #         # Standard response message
      #         response_value = dispatch_call :method => m.target_uri, :args => m.data, :source => m, :block => block
      #     end
      # 
      #     target_uri = m.response_uri
      #     target_uri += response_value.is_a?(Messages::ErrorMessage) ? '/onStatus' : '/onResult'
      #     @messages << ::RocketAMF::Message.new(target_uri, '', response_value)
      #   end
      # 
      #   @constructed = true
      # end
    end
    
    class Header
      attr_accessor :name, :data, :required

      def initialize(name, data, required)
        @name = name
        @data = data
        @required = required
      end
    end
    
    class Body
      attr_accessor :target_uri, :response_uri, :data

      def initialize target_uri, response_uri, data
        @target_uri = target_uri
        @response_uri = response_uri
        @data = data
      end
    end
    
  end
end