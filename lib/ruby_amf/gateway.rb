require 'zlib'
module RubyAMF
  class Gateway
    @@service_path = File.expand_path(Rails.root) + '/app/controllers'
    cattr_accessor  :service_path,
                    :service,
                    :action,
                    :service_result,
                    :capture_incoming_amf,
                    :gzip,
                    :env,
                    :request,
                    :authentication,
                    :response
    
    class << self
      include RubyAMF::Exceptions
      include RubyAMF::Configuration
      include RubyAMF::AMF
      include RubyAMF::AMF::Utils
      
      # fully valid Rack application
      def call(env)
        self.authentication = nil # clear authentication
        self.request = ActionDispatch::Request.new(env)
        self.response = ActionDispatch::Response.new
        self.gzip = env['ACCEPT_ENCODING'].to_s.match(/gzip,[\s]{0,1}deflate/)

        if self.request.content_type != "application/x-amf"
          return self.html_response
        else
          amfobj = AMFObject.new(self.request.raw_post)
          amfobj.bodies.each do |amfbody|
            
            if amfbody.exec == false
              if amfbody.special_handling == 'Ping'
                amfbody.results = create_acknowledge_object(amfbody.get_meta('messageId'), amfbody.get_meta('clientId')) #generate an empty acknowledge message here, no body needed for a ping
                amfbody.success! #set the success response uri flag (/onResult)
              end
              next
            end
            
            begin #this is where any RubyAMF exception during service call gets transformed into a relevant AMF0/AMF3 faultObject
              self.invoke_service_call(amfbody)
              
            rescue RUBYAMFException => ramfe
              ramfe.ebacktrace = ramfe.backtrace.to_s
              ExceptionHandler::HandleException(ramfe, amfbody)
              
            rescue Exception => e
              ramfe = RUBYAMFException.new(e.class.to_s, e.message.to_s)
              ramfe.ebacktrace = e.backtrace.to_s
              ExceptionHandler::HandleException(ramfe, amfbody)
            end
          end
          self.response = build_amf_response(amfobj)
          
          self.response
        end
      end

      protected
        def invoke_service_call(amfbody)
          self.request = replace_env_params(amfbody)
          self.service = find_service(amfbody)
          self.action = amfbody.service_method_name.to_sym
          
          #process the request params
          rubyamf_params = {}
          if amfbody.value && !amfbody.value.empty?
            amfbody.value.each_with_index { |item,i| rubyamf_params[i] = item }
          end

          # put them by default into the parameter hash if they opt for it
          rubyamf_params.each{|k,v| self.request.parameters[k] = v} if ParameterMappings.always_add_to_params       

          # what is this doing? needed?
          # One last update of the parameters hash, this will map custom mappings to the hash, and will override any conflicting from above
          begin
            ParameterMappings.update_request_parameters(amfbody.service_class_name, amfbody.service_method_name, self.request.parameters, rubyamf_params, amfbody.value)
          rescue Exception => e
            raise RUBYAMFException.new(RUBYAMFException.PARAMETER_MAPPING_ERROR, "There was an error with your parameter mappings: {#{e.message}}")
          end

          self.service.is_amf = true # set conditional helper
          self.service.rubyamf_params = rubyamf_params # add the rubyamf_args into the controller to be accessed
          
          self.service.request = self.request
          self.service.response = self.response
          self.service.process(self.action)
          
          self.service.is_amf = false #unset conditional helper
          self.service.rubyamf_params = {}

          result = self.service_result

          #handle FaultObjects
          if result.class.to_s == 'FaultObject' #catch returned FaultObjects - use this check so we don't have to include the fault object module
            e = RUBYAMFException.new(result['code'], result['message'])
            e.payload = result['payload']
            raise e
          end

          #amf3
          amfbody.results = result
          if amfbody.special_handling == 'RemotingMessage'
            wrapper = create_acknowledge_object(amfbody.get_meta('messageId'), amfbody.get_meta('clientId'))
            wrapper["body"] = result
            amfbody.results = wrapper
          end
          amfbody.success! #set the success response uri flag (/onResult)
        end
        
        def find_service(amfbody)
          class_file_path = amfbody.service_class_file_path
          class_name = amfbody.service_class_name
          method_name = amfbody.service_method_name
          
          begin
            service_object = class_name.constantize.new #handle on service
          rescue Exception => e
            raise RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "There was an error loading the service class #{class_name}")
          end
          
          if service_object.private_methods.any? { |m| m.to_s == method_name }
            raise RUBYAMFException.new(RUBYAMFException.METHOD_ACCESS_ERROR, "The method {#{method_name}} in class {#{class_file_path}} is declared as private, it must be defined as public to access it.")
          elsif !service_object.public_methods.any? { |m| m.to_s == method_name }
            raise RUBYAMFException.new(RUBYAMFException.METHOD_UNDEFINED_METHOD_ERROR, "The method {#{method_name}} in class {#{class_file_path}} is not declared.")
          end
          
          service_object
        end
        
        def replace_env_params(amfbody)
          controller = amfbody.service_class_name.gsub("Controller","").underscore
          action     = amfbody.service_method_name

          service_request = self.request.clone
          
          service_request.parameters['controller']  = service_request.request_parameters['controller'] = service_request.path_parameters['controller'] = controller
          service_request.parameters['action']      = service_request.request_parameters['action']     = service_request.path_parameters['action']     = action
          service_request.env['PATH_INFO']          = service_request.env['REQUEST_PATH']              = service_request.env['REQUEST_URI']            = "#{controller}/#{action}"
          service_request.env['HTTP_ACCEPT']        = 'application/x-amf'
          
          service_request
        end
      
        def build_amf_response(amfobj)
          amfobj.serialize!
          amf_response = self.gzip ? Zlib::Deflate.deflate(amfobj.output_stream) : amfobj.output_stream
          
          [200, {"Content-Type" => "application/x-amf"}, amf_response]
        end
      
        def html_response
          [ 200,
            {"Content-Type" => "text/html"},
            ["<html>
                <head>
                  <title>RubyAMF Gateway</title>
                  <style>body{margin:0;padding:0;font:12px sans-serif;color:#c8c8c8}td{font:12px sans-serif}</style>
                </head>
                <body bgcolor='#222222'>
                <table width='100%' align=center valign=middle height='100%'><tr><td width=100 align=center>
                  <a href='http://blog.rubyamf.org'><img border=0 src='http://blog.rubyamf.org/images/gateway.png' /></a>
                </table>
                </body>
              </html>"]
          ]
        end
    end

    # def initialize
    #   RequestStore.filters = Array[AMFDeserializerFilter.new, AuthenticationFilter.new, BatchFilter.new, AMFCaptureFilter.new, AMFSerializeFilter.new] #create the filter
    #   RequestStore.actions = Array[PrepareAction.new, RailsInvokeAction.new] #override the actions
    # end
    # 
    # #all get and post requests circulate throught his method
    # def service(raw)
    #   amfobj = AMFObject.new(raw)
    #   FilterChain.new.run(amfobj)
    #   RequestStore.gzip ? Zlib::Deflate.deflate(amfobj.output_stream) : amfobj.output_stream
    # end
    
    # TODO: Reimplement authentication
    # if (auth_header = amfobj.get_header_by_key('Credentials'))
    #   RequestStore.auth_header = auth_header #store the auth header for later
    #   case ClassMappings.hash_key_access
    #   when :string then
    #     auth = {'username' => auth_header.value['userid'], 'password' => auth_header.value['password']}
    #   when :symbol then
    #     auth = {:username => auth_header.value['userid'], :password => auth_header.value['password']}
    #   when :indifferent then
    #     auth = HashWithIndifferentAccess.new({:username => auth_header.value['userid'], :password => auth_header.value['password']})
    #   end
    #   RequestStore.rails_authentication = auth
    # end
    
  end
end