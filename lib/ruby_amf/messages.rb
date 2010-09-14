module RubyAMF
  module Messages #:nodoc:
    # Base class for all special AS3 response messages. Maps to
    # <tt>flex.messaging.messages.AbstractMessage</tt>.
    class AbstractMessage
      attr_accessor :clientId
      attr_accessor :destination
      attr_accessor :messageId
      attr_accessor :timestamp
      attr_accessor :timeToLive
      attr_accessor :headers
      attr_accessor :body

      protected
        def rand_uuid
          [8,4,4,4,12].map {|n| rand_hex_3(n)}.join('-').to_s
        end

        def rand_hex_3(l)
          "%0#{l}x" % rand(1 << l*4)
        end
    end

    # Maps to <tt>flex.messaging.messages.RemotingMessage</tt>
    class RemotingMessage < AbstractMessage
      attr_accessor :source # The name of the service to be called including package name
      attr_accessor :operation # The name of the method to be called
      attr_accessor :parameters # The arguments to call the method with

      def initialize
        @clientId = rand_uuid
        @destination = nil
        @messageId = rand_uuid
        @timestamp = Time.new.to_i*100
        @timeToLive = 0
        @headers = {}
        @body = nil
      end
      
      def target_uri
        [@source.to_s, @operation.to_s].reject(&:blank?).join(".")
      end
      
      def params
        @body
      end
    end

    # Maps to <tt>flex.messaging.messages.AsyncMessage</tt>
    class AsyncMessage < AbstractMessage
      attr_accessor :correlationId
    end

    # Maps to <tt>flex.messaging.messages.CommandMessage</tt>
    class CommandMessage < AsyncMessage
      SUBSCRIBE_OPERATION           = 0
      UNSUSBSCRIBE_OPERATION        = 1
      POLL_OPERATION                = 2
      CLIENT_SYNC_OPERATION         = 4
      CLIENT_PING_OPERATION         = 5
      CLUSTER_REQUEST_OPERATION     = 7
      LOGIN_OPERATION               = 8
      LOGOUT_OPERATION              = 9
      SESSION_INVALIDATE_OPERATION  = 10
      MULTI_SUBSCRIBE_OPERATION     = 11
      DISCONNECT_OPERATION          = 12
      UNKNOWN_OPERATION             = 10000

      attr_accessor :operation

      def initialize
        @operation = UNKNOWN_OPERATION
      end
    end

    # Maps to <tt>flex.messaging.messages.AcknowledgeMessage</tt>
    class AcknowledgeMessage < AsyncMessage
      def initialize(message = nil, body = nil)
        @clientId = rand_uuid
        @destination = nil
        @messageId = rand_uuid
        @timestamp = Time.new.to_i*100
        @timeToLive = 0
        @headers = {}
        @body = body

        if message.is_a?(AbstractMessage)
          @correlationId = message.messageId
        end
      end
    end

    # Maps to <tt>flex.messaging.messages.ErrorMessage</tt> in AMF3 mode
    class ErrorMessage < AcknowledgeMessage
      # Extended data that will facilitate custom error processing on the client
      attr_accessor :extendedData      
      attr_accessor :faultCode # The fault code for the error, defaults to class name
      attr_accessor :faultDetail # Detailed description of what caused the error
      attr_accessor :faultString # A simple description of the error
      attr_accessor :rootCause # Optional "root cause" of the error
 
      def initialize(message = nil, exception = nil)
        super message

        unless exception.nil?
          @e = exception
          @faultCode = @e.class.name
          @faultDetail = @e.backtrace.join("\n")
          @faultString = @e.message
        end
      end
    end
  end
end