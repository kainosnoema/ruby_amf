module RubyAMF
  module Remoting
    # Container for the AMF request/response.
    class Envelope
      include RubyAMF::Messages
      
      attr_reader :amf_version, :headers, :bodies

      def initialize(stream = nil)
        if stream
          deserialize(stream) # calls method implemented in native C extension
        else
          @amf_version = 0
          @headers = []
          @bodies = []
        end
      end
      
      def deserialize(stream)
        raise 'should have been overridden by the RubyAMF::Ext::AMFRemoting native extension!'
      end
      
      def serialize
        raise 'should have been overridden by the RubyAMF::Ext::AMFRemoting native extension!'
      end
      
      # Builds response from the request, iterating over each method and calling
      # the provided block with the remoting service method and parameters
      def each_method_call request, &block
        raise 'Response already constructed' if @bodies.length > 0
        
        @amf_version = request.amf_version == 3 ? 3 : 0
        
        request.bodies.each do |b|
          if b.data.is_a?(Array) && b.data.length == 1 && b.data[0].is_a?(AbstractMessage)
            b.data = b.data[0]
          end
          
          case b.data
            when CommandMessage
              command_msg = b.data
              if command_msg.operation == CommandMessage::CLIENT_PING_OPERATION
                response = AcknowledgeMessage.new(command_msg)
              else
                e = Exception.new("CommandMessage #{command_msg.operation} not implemented")
                e.set_backtrace ["RubyAMF::Remoting::Envelope each_method_call"]
                response = ErrorMessage.new(command_msg, e)
              end
            when RemotingMessage
              remoting_msg = b.data
              service_method = [remoting_msg.source.to_s, remoting_msg.operation].reject(&:blank?).join(".")
              
              # attempt to call the block using the remote message body, catch any exceptions
              body = call_service(  :method => service_method,
                                    :params => remoting_msg.body,
                                    :source => remoting_msg,
                                    :block => block)

              if body.is_a?(ErrorMessage)
                response = body
              else
                acknowledge_msg = AcknowledgeMessage.new(remoting_msg)
                acknowledge_msg.body = body
                response = acknowledge_msg
              end

            else
              response = call_service( :method => b.target_uri, :params => b.data, :source => b, :block => block)
          end
      
          target_uri = b.response_uri + (response.is_a?(ErrorMessage) ? '/onStatus' : '/onResult')
          @bodies << Body.new(target_uri, '', response)
        end
      end
      
      private
        def call_service args
          begin
            args[:block].call(args[:method], args[:params])
          rescue Exception => e
            ErrorMessage.new(args[:source], e)
          end
        end
    end
    
    class Header
      attr_accessor :name, :must_understand, :data

      def initialize(name, must_understand, data)
        @name = name
        @must_understand = must_understand
        @data = data
      end
    end
    
    class Body
      attr_accessor :target_uri, :response_uri, :data

      def initialize(target_uri, response_uri, data)
        @target_uri = target_uri
        @response_uri = response_uri
        @data = data
      end
    end
    
  end
end