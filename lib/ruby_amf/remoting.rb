module RubyAMF
  module Remoting
    AMF_MIME_TYPE = "application/x-amf".freeze

    # Containers for the AMF request/response
    class Envelope
      include RubyAMF::Messages
      attr_reader :amf_version, :headers, :bodies

      def deserialize(stream = "")
        raise 'deserialize() should have been overridden by either RubyAMF::Pure or RubyAMF::Ext, the native extension!'
      end
            
      def serialize
        raise 'serialize() should have been overridden by either RubyAMF::Pure or RubyAMF::Ext, the native extension!'
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

        def params
          @data
        end
      end
    end
    
    class Response < Envelope
      def initialize(params = {})
        @amf_version = params[:amf_version] || 0
        @headers = []
        @bodies = []
      end
    end
    
    class Request < Envelope
      # initialize the envelope using an ActionDispatch::Request
      # automatically deserializes the AMF message data
      def initialize(request = nil)
        if request.is_a?(ActionDispatch::Request)
          deserialize(request.raw_post) # calls method implemented in native C extension
        else
          @amf_version = 0
          @headers = []
          @bodies = []
        end
      end
      
      # Builds response from the request, iterating over each method and calling
      # the provided block with the remoting service method and parameters
      def each_message &block
        response_envelope = Response.new({:amf_version => (@amf_version == 3 ? 3 : 0)})
        
        @bodies.each do |body|
          if body.data.is_a?(Array) && body.data.length == 1 && body.data[0].is_a?(AbstractMessage)
            message = body.data[0]
          else
            message = body.data
          end
          
          case message
            when CommandMessage
              if message.operation == CommandMessage::CLIENT_PING_OPERATION
                response_msg = AcknowledgeMessage.new(message)
              else
                e = Exception.new("CommandMessage #{message.operation} not implemented")
                e.set_backtrace ["RubyAMF::Remoting::Request each_message"]
                response_msg = ErrorMessage.new(message, e)
              end
              
            when RemotingMessage
              # attempt to call the block using the remote message body, catch any exceptions
              response_msg = call_block_with(message, &block)
              response_msg = AcknowledgeMessage.new(message, response_msg) unless response_msg.is_a?(ErrorMessage)
              
            else
              response_msg = call_block_with(body, &block)
          end
      
          response_target_uri = body.response_uri + (response_msg.is_a?(ErrorMessage) ? '/onStatus' : '/onResult')
          response_envelope.bodies << Body.new(response_target_uri, '', response_msg)
        end
        
        return response_envelope
      end
      
      private
        def call_block_with message, &block
          begin
            block.call(message)
          rescue Exception => e
            ErrorMessage.new(message, e)
          end
        end
    end
    
    class Service
      attr_reader :message, :request, :controller, :action_name
      
      def initialize(message, original_request)
        @message = message
        @request = original_request.clone
        
        # AMF operation maps directly to action name
        @action_name = @message.operation.to_sym

        # find, instantiate and prepare controller
        controller_class_name = @message.source.split(".").collect(&:camelize).join("::")
        @controller = find_controller_for(controller_class_name)
        
        # set new controller and action names
        [@request.parameters, @request.request_parameters, @request.path_parameters].each do |req_params|
          req_params['controller'] = @controller.controller_name
          req_params['action']     = @action_name.to_s
        end

        # set new path info & accept mime type
        path_info = "#{@controller.controller_path}/#{@action_name}"
        ['PATH_INFO', 'REQUEST_PATH', 'REQUEST_URI'].each { |key| @request.env[key] = path_info }
        @request.env['HTTP_ACCEPT'] = AMF_MIME_TYPE

        # process the request params and put them in the controller params
        if @message.params.present?
          @controller.amf_params = @message.params # add original array for easy access
          @message.params.each_with_index do |item, i|
            @request.parameters[i] = item
          end
        end

        # set the controller request to our updated request
        @controller.request = @request
        @controller.response = ActionDispatch::Response.new # prevents errors
        @controller.is_amf = true # set our conditional helper
      end
      
      def process
        @controller.process(@action_name)
        @controller.processed_amf
      end
         
      private
        def find_controller_for(controller_class_name)
          controller_class = ActiveSupport::Dependencies.ref(controller_class_name).get

          # check class
          unless (controller_class_name =~ /^[A-Za-z:]+Controller$/ && 
            controller_class.respond_to?(:controller_name) && controller_class.respond_to?(:action_methods))
            raise Exception.new("The service class #{controller_class_name} does not exist")
          end

          # check action
          unless controller_class.action_methods.include?(@action_name)
            raise Exception.new("The service class #{controller_class_name} does not respond to #{@action_name}")
          end

          # instantiate, rescue load exceptions
          begin
            controller = controller_class.new
          rescue Exception => e
            exc = e.exception("Unable to load the service class #{controller_class_name}: #{e.message}")
            exc.set_backtrace(e.backtrace)
            raise exc
          end
          
          controller
        end
    end
  end
end