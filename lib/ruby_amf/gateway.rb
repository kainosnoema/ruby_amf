require 'zlib'
require 'benchmark'
module RubyAMF
  class Gateway
    class << self
      
      def call(env)
        @use_gzip = env['ACCEPT_ENCODING'].to_s.match(/gzip,[\s]{0,1}deflate/)
        @request = ActionDispatch::Request.new(env)

        if @request.content_type != Remoting::AMF_MIME_TYPE
          return html_response
        else
          begin
            amf_request = Remoting::Request.new(@request)
            
            # handle each method call in the request and build the response
            amf_response = amf_request.each_message do |msg|
              Remoting::Service.new(msg, @request).process # calls action and returns result
            end

            Rails.logger.warn "serializing"
            
            response_str = @use_gzip ? Zlib::Deflate.deflate(amf_response.serialize) : amf_response.serialize
            
          rescue Exception => e
            Rails.logger.warn e.message.to_s
            Rails.logger.warn e.backtrace.take(10).join("\n")
          end
          
          return [200, {"Content-Type" => Remoting::AMF_MIME_TYPE}, response_str]
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