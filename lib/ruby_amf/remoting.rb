module RubyAMF
  module Remoting
    # Containers for the AMF request/response
    class Envelope
      include RubyAMF::Messages
      attr_reader :action_dispatch_request, :amf_version, :headers, :bodies
      
      def deserialize(stream = "")
        raise 'should have been overridden by the RubyAMF::Ext::AMFRemoting native extension!'
      end
            
      def serialize
        raise 'should have been overridden by the RubyAMF::Ext::AMFRemoting native extension!'
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
    
    class Response < Envelope
      def initialize(params = {})
        @amf_version = params[:amf_version] || 0
        @headers = []
        @bodies = []
      end
    end
    
    class Request < Envelope
      attr_reader :target_uri, :params

      # initialize the envelope using an ActionDispatch::Request
      # automatically deserializes the AMF message data
      def initialize(request = nil)
        if request.is_a?(ActionDispatch::Request)
          @action_dispatch_request = request
          deserialize(@action_dispatch_request.raw_post) # calls method implemented in native C extension
        else
          @amf_version = 0
          @headers = []
          @bodies = []
        end
      end
      
      # Builds response from the request, iterating over each method and calling
      # the provided block with the remoting service method and parameters
      def each_method_call &block
        response_envelope = Response.new({:amf_version => (@amf_version == 3 ? 3 : 0)})
        
        @bodies.each do |b|
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
              body = call_service(  :target_uri => service_method,
                                    :params => remoting_msg.body,
                                    :source => remoting_msg,
                                    :block => block)

              if body.is_a?(ErrorMessage)
                response_msg = body
              else
                acknowledge_msg = AcknowledgeMessage.new(remoting_msg)
                acknowledge_msg.body = body
                response_msg = acknowledge_msg
              end

            else
              response_msg = call_service( :target_uri => b.target_uri, :params => b.data, :source => b, :block => block)
          end
      
          target_uri = b.response_uri + (response_msg.is_a?(ErrorMessage) ? '/onStatus' : '/onResult')
          response_envelope.bodies << Body.new(target_uri, '', response_msg)
        end
        
        return response_envelope
      end
      
      def find_service
        RubyAMF::Remoting.find_service_for(self)
      end
      
      private
        def call_service args
          begin
            @target_uri = args[:target_uri]
            @params = args[:params]
            args[:block].call(self)
          rescue Exception => e
            ErrorMessage.new(args[:source], e)
          end
        end
    end
    
    class Service
      attr_reader :controller, :action
      
      def initialize(controller, action)
        @controller = controller
        @action = action
      end
    end
    
    def find_service_for(request)
      target_uri = request.target_uri
      params = request.params
      
      uri_elements =  target_uri.split(".")
      action_name = uri_elements.pop
      
      uri_elements.last << "Controller" unless uri_elements.last.include?("Controller")
      service_class_name = uri_elements.collect(&:camelize).join("::")

      begin
        service_controller = service_class_name.constantize.new # handle on service
      rescue Exception => e
        Rails.logger.warn e.message.to_s
        Rails.logger.warn e.backtrace.take(5).join("\n")
        # raise RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "There was an error loading the service class #{class_name}")
        raise Exception.new("There was an error calling the service")
      end
      
      if service_controller.private_methods.any? { |m| m.to_s == action_name }
        # raise RUBYAMFException.new(RUBYAMFException.METHOD_ACCESS_ERROR, "The method {#{action_name}} in class {#{class_file_path}} is declared as private, it must be defined as public to access it.")
        raise Exception.new("There was an error calling the service")
      elsif !service_controller.public_methods.any? { |m| m.to_s == action_name }
        # raise RUBYAMFException.new(RUBYAMFException.METHOD_UNDEFINED_METHOD_ERROR, "The method {#{action_name}} in class {#{class_file_path}} is not declared.")
        raise Exception.new("There was an error calling the service")
      end
      
      service_req = request.action_dispatch_request.clone
      controller_name = service_class_name.gsub("Controller","").underscore
      
      # set new controller and action names
      [service_req.parameters, service_req.request_parameters, service_req.path_parameters].each do |params|
        params['controller'] = controller_name
        params['action']     = action_name
      end
      
      # set new path info
      ['PATH_INFO', 'REQUEST_PATH', 'REQUEST_URI'].each do |path_env_key|
        service_req.env[path_env_key] = "#{controller_name}/#{action_name}"
      end

      # set new accept mime type
      service_req.env['HTTP_ACCEPT']        = 'application/x-amf'
      
      # process the request params put them
      rubyamf_params = {}
      if params && !params.empty?
        # add original array for easy access
        service_req.parameters[:ruby_amf_params] = params
        # also put each in the request parameter hash
        params.each_with_index { |item, i| service_req.parameters[i] = item }
      end
      
      # set the controller request to our updated request
      service_controller.request = service_req
      service_controller.response = ActionDispatch::Response.new # prevents errors
      
      return Service.new(service_controller, action_name.to_sym)
    end
    
  end
end