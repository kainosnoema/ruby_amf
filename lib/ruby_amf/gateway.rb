require 'zlib'
require 'benchmark'
module RubyAMF
  class Gateway
    class << self
      
      def call(env)
        bench_start
        
        @request = ActionDispatch::Request.new(env)
        @use_gzip = env['ACCEPT_ENCODING'].to_s.match(/gzip,[\s]{0,1}deflate/)

        if @request.content_type != Remoting::AMF_MIME_TYPE
          return html_response
        else
          begin
            amf_request = Remoting::Request.new(@request)

            # handle each message in the request and build the response
            amf_response = amf_request.each_message do |msg|
              service = Remoting::Service.new(msg, @request)
              RubyAMF.logger.info("Started \"/#{service.request.path_info}\" for #{@request.remote_ip} at #{Time.zone.now.strftime(RubyAMF::LOG_TIME_FORMAT)}")
              service.process # calls action and returns result
            end

            response_str = @use_gzip ? Zlib::Deflate.deflate(amf_response.serialize) : amf_response.serialize
            
            unless amf_request.command_message?
              RubyAMF.logger.info "Finished in #{bench_current}ms\n\n"
            end
          rescue Exception => e
            RubyAMF.logger.error(RubyAMF.colorize("Error: #{e.message.to_s}", 35) + "\n" + e.backtrace.take(10).join("\n"))
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
        
        def bench_start
          @t_start = Time.now
          true
        end

        def bench_current
          ((Time.now - @t_start)*1000).round
        end
    end    
  end
end