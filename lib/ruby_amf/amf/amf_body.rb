# Wraps an amfbody with methods and params for easter manipulation

module RubyAMF
  module AMF
    class AMFBody
      include RubyAMF::Exceptions
      include RubyAMF::Configuration
      include RubyAMF::VoHelper
  
      attr_accessor :id             #the amfbody id
      attr_accessor :amf_encoding   #the amf encoding type (amf0 or amf3)
      attr_accessor :flex_message   #when its a remoting message, not command message
      attr_accessor :response_index #the response unique index that the player understands, knows which result / fault methods to call.
      attr_accessor :response_uri   #the complete response uri (EX: /12/onStatus)  
      attr_accessor :target_uri     #the target uri (service name)  
      attr_accessor :service_class_file_path   #the service file path
      attr_accessor :service_class_name        #the service name  
      attr_accessor :service_method_name       #the service method name
      attr_accessor :value          #the parameters to use in the service call 
      attr_accessor :results        #the results from a service call
      attr_accessor :special_handling     #special handling
      attr_accessor :exec           #executeable body
      attr_accessor :_explicitType  #set the explicit type

      #create a new amfbody object
      def initialize(target_uri = "", response_index = "", value = "")
        @id = response_index.clone.split('/').to_s
        @amf_encoding = "amf3"
        @flex_message = true
        @target_uri = target_uri
        @response_index = response_index
        @response_uri = @response_index + '/onStatus' #default to status call
        @value = value
        @exec = true
        @_explicitType = ""
        @meta = {}
        
        process_message_body
      end

      def process_message_body
        if amf_encoding == 'amf3' && (raw_body = self.value[0]).is_a?(VoHash) &&
            ['flex.messaging.messages.RemotingMessage','flex.messaging.messages.CommandMessage'].include?(raw_body._explicitType)
          case raw_body._explicitType
          when 'flex.messaging.messages.RemotingMessage' #Flex Messaging setup
            ClassMappings.use_array_collection = !(ClassMappings.use_array_collection == false) # it will only set it to false if the user specifically sets use_array_collection to false
            self.flex_message = true # only set RequestStore and ClassMappings when its a remoting message, not command message
            self.special_handling = 'RemotingMessage'
            self.value = raw_body['body']
            self.set_meta('clientId', raw_body['clientId'])
            self.set_meta('messageId', raw_body['messageId'])
            self.target_uri = raw_body['source']
            self.service_method_name = raw_body['operation']
            self._explicitType = raw_body._explicitType
          when 'flex.messaging.messages.CommandMessage' #it's a ping, don't process this body, and hence, dont set service uri information
            if raw_body['operation'] == 5
              self.exec = false
              self.special_handling = 'Ping'
              self.set_meta('clientId', raw_body['clientId'])
              self.set_meta('messageId', raw_body['messageId'])
            end
            return # we don't want it to run process_service_uri
          end
        else
          ClassMappings.use_array_collection = false # ensure that array_collection is disabled 
          self.flex_message = false
        end

        process_service_uri
      end

      # allows a target_uri of "services.[bB]ooks", "services.[bB]ooksController to become service_class_name "Services::BooksController" and the class file path to be "services/books_controller.rb" 
      def process_service_uri
        if @target_uri 
          uri_elements =  @target_uri.split(".") 
          @service_method_name ||= uri_elements.pop # this was already set, probably amf3, that means the target_uri doesn't include it
          if !uri_elements.empty?
            uri_elements.last << "Controller" unless uri_elements.last.include?("Controller")
            @service_class_name      = uri_elements.collect(&:to_title).join("::")
            @service_class_file_path = "#{RubyAMF::Gateway.service_path}/#{uri_elements[0..-2].collect{|x| x+'/'}.join}#{uri_elements.last.underscore}.rb"
          else
            raise RUBYAMFException.new(RUBYAMFException.SERVICE_TRANSLATION_ERROR, "The correct service information was not provided to complete the service call. The service and method name were not provided")
          end
        else
          if flex_message
            raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "There is no \"source\" property defined on your RemoteObject, please see RemoteObject documentation for more information.")
          else
            raise RUBYAMFException.new(RUBYAMFException.SERVICE_TRANSLATION_ERROR, "The correct service information was not provided to complete the service call. The service and method name were not provided")
          end
        end
      end
      
      #append string data the the response uri
      def append_to_response_uri(str)
        @response_uri = @response_uri + str
      end
  
      #set some meta data for this amfbody
      def set_meta(key,val)
        @meta[key] = val
      end
  
      #get the meta data by key
      def get_meta(key)
        @meta[key]
      end
  
      #trigger an update to the response_uri to be a successfull response (/1/onResult)
      def success!
        @response_uri = "#{@response_index}/onResult"
      end
  
      #force the call to fail in the flash player
      def fail!
        @response_uri = "#{@response_index}/onStatus"
      end
  
    end
  end
end