require 'zlib'
module RubyAMF
  class Gateway
    include RubyAMF::Remoting
    
    @@service_path = File.expand_path(Rails.root) + '/app/controllers'
    cattr_accessor  :env,
                    :request,
                    :response,
                    :service_result,
                    :service_path,
                    :service,
                    :action,
                    :gzip
    
    class << self
      
      # valid Rack application
      def call(env)
        self.request = ActionDispatch::Request.new(env)
        self.response = ActionDispatch::Response.new # prevents errors
        self.gzip = env['ACCEPT_ENCODING'].to_s.match(/gzip,[\s]{0,1}deflate/)

        if self.request.content_type != "application/x-amf"
          return self.html_response
        else
          begin
            amf_request = RubyAMF::Remoting::Envelope.new(self.request.raw_post)

            # handle requests
            amf_response = RubyAMF::Remoting::Envelope.new
            amf_response.each_method_call(amf_request) do |target_uri, args|
              call_service_controller(target_uri, args)
            end
            
            response_str = if self.gzip
              Zlib::Deflate.deflate(amf_response.serialize)
            else
              amf_response.serialize
            end

          rescue Exception => e
            Rails.logger.warn e.message.to_s
            Rails.logger.warn e.backtrace.take(5).join("\n")
          end
                  
          return [200, {"Content-Type" => "application/x-amf"}, response_str]
        end
      end

      protected
        def call_service_controller(target_uri, args)
          uri_elements =  target_uri.split(".")
          action_name = uri_elements.pop
          uri_elements.last << "Controller" unless uri_elements.last.include?("Controller")
          service_class_name = uri_elements.collect(&:camelize).join("::")
          
          begin
            self.service = service_class_name.constantize.new #handle on service
            self.action = action_name.to_sym
          rescue Exception => e
            Rails.logger.warn e.message.to_s
            Rails.logger.warn e.backtrace.take(5).join("\n")
            # raise RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "There was an error loading the service class #{class_name}")
            raise Exception.new("There was an error calling the service")
          end
          
          if self.service.private_methods.any? { |m| m.to_s == action_name }
            # raise RUBYAMFException.new(RUBYAMFException.METHOD_ACCESS_ERROR, "The method {#{action_name}} in class {#{class_file_path}} is declared as private, it must be defined as public to access it.")
            raise Exception.new("There was an error calling the service")
          elsif !self.service.public_methods.any? { |m| m.to_s == action_name }
            # raise RUBYAMFException.new(RUBYAMFException.METHOD_UNDEFINED_METHOD_ERROR, "The method {#{action_name}} in class {#{class_file_path}} is not declared.")
            raise Exception.new("There was an error calling the service")
          end
          
          controller_name = service_class_name.gsub("Controller","").underscore
        
          self.request.parameters['controller']  = self.request.request_parameters['controller'] = self.request.path_parameters['controller'] = controller_name
          self.request.parameters['action']      = self.request.request_parameters['action']     = self.request.path_parameters['action']     = action_name
          self.request.env['PATH_INFO']          = self.request.env['REQUEST_PATH']              = self.request.env['REQUEST_URI']            = "#{controller_name}/#{action_name}"
          self.request.env['HTTP_ACCEPT']        = 'application/x-amf'
          
          #process the request params
          rubyamf_params = {}
          if args && !args.empty?
            args.each_with_index { |item,i| rubyamf_params[i] = item }
          end
        
          # put them by default into the parameter hash
          self.request.parameters.merge! rubyamf_params
          
          self.service.is_amf = true # set conditional helper
          self.service.rubyamf_params = rubyamf_params # add the rubyamf_args into the controller to be accessed
          
          self.service.request = self.request
          self.service.response = self.response
          self.service.process(self.action)
          
          self.service.is_amf = false #unset conditional helper
          self.service.rubyamf_params = {}
          
          return self.service_result
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
  end
end