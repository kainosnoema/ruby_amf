require 'zlib'
require 'benchmark'
module RubyAMF
  class Gateway
    include RubyAMF::Remoting
    
    @@service_path = File.expand_path(Rails.root) + '/app/controllers'
    cattr_accessor  :env,
                    :gzip,
                    :request
    
    class << self
      
      # valid Rack application
      def call(env)
        self.env = env
        self.gzip = env['ACCEPT_ENCODING'].to_s.match(/gzip,[\s]{0,1}deflate/)
        self.request = ActionDispatch::Request.new(env)

        if self.request.content_type != "application/x-amf"
          return self.html_response
        else
          begin
            
            amf_request = RubyAMF::Remoting::Request.new(self.request)
            
            # handle each method call in the request and build the response
            amf_response = amf_request.each_method_call do |method_call|
              # can get these directly and process manually:
              #     target_uri = method_call.target_uri
              #     params = method_call.params
              
              # or we can find and initialize the service automatically:
              service = method_call.find_service
              service.controller.process_as_amf(service.action)
              return service.controller.rendered_amf
            end
            
            Rails.logger.warn amf_response.inspect
            
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