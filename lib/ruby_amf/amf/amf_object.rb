#A High level amf message wrapper with methods for easy header and body manipulation

module RubyAMF
  module AMF
    class AMFObject
      include RubyAMF::AMFIo
      include RubyAMF::Exceptions

      #raw input stream, serialized output stream
      attr_accessor :amf_encoding, :input_stream, :output_stream, :bodies
    
      #create a new AMFObject, pass the raw request data
      def initialize(raw_post = nil)
        @amf_encoding = 'amf3'
        @input_stream = raw_post
        @output_stream = ""
        @inheaders = Array.new
        @outheaders = Array.new
        @bodies = Array.new
        @header_table = Hash.new
        
        deserialize! if !@input_stream.nil?
      end
      
      def deserialize!
        begin
          AMFDeserializer.new(self).run
        rescue RUBYAMFException => ramfe
          ramfe.ebacktrace = ramfe.backtrace.to_s
          ExceptionHandler::HandleException(ramfe, self.get_body_at(0))
        rescue Exception => e
          ramfe = RUBYAMFException.new(e.class.to_s, e.message.to_s) #translate the exception into a rubyamf exception
          ramfe.ebacktrace = e.backtrace.to_s
          ExceptionHandler::HandleException(ramfe, self.get_body_at(0))
        end
      end
      
      def serialize!
        begin
          AMFSerializer.new(self).run
        rescue RUBYAMFException => ramfe
          ramfe.ebacktrace = ramfe.backtrace.to_s
          ExceptionHandler::HandleException(ramfe, self.get_body_at(0))
        rescue Exception => e
          ramfe = RUBYAMFException.new(e.class.to_s, e.message.to_s) #translate the exception into a rubyamf exception
          ramfe.ebacktrace = e.backtrace.to_s
          ExceptionHandler::HandleException(ramfe, self.get_body_at(0))
        end
      end

      #add a raw header to this amf_object
      def add_header(amf_header)
        @inheaders << amf_header
        @header_table[amf_header.name] = amf_header
      end

      #get a header by it's key
      def get_header_by_key(key)
        @header_table[key]||false
      end

      #get a header at a specific index
      def get_header_at(i=0)
        @inheaders[i]||false
      end

      #get the number of in headers
      def num_headers
        @inheaders.length
      end

      #add a parse header to the outgoing pool of headers
      def add_outheader(amf_header)
        @outheaders << amf_header
      end

      #get a header at a specific index
      def get_outheader_at(i=0)
        @outheaders[i] || false
      end

      #get all the in headers
      def get_outheaders
        @outheaders
      end

      #Get the number of out headers
      def num_outheaders
        @outheaders.length
      end

      #add a body
      def add_body(amf_body)
        amf_body.amf_encoding = self.amf_encoding
        @bodies << amf_body
      end

      #get a body obj at index
      def get_body_at(i=0)
        @bodies[i] || false
      end

      #get the number of bodies
      def num_body
        @bodies.length
      end

      #add a body to the body pool at index
      def add_body_at(index,body)
        @bodies.insert(index,body)
      end
  
      #add a body to the top of the array
      def add_body_top(body)
        @bodies.unshift(body)
      end

      #Remove a body from the body pool at index
      def remove_body_at(index)
        @bodies.delete_at(index)
      end
  
      #remove the AUTH header, (it is always at the top)
      def remove_auth_body
        @bodies.shift
      end
  
      #remove all bodies except the auth body
      def only_auth_fail_body!
        auth_body = nil
        @bodies.each do |b|
          if b.inspect.to_s.match(/Authentication Failed/) != 
            auth_body = b
          end
        end
        @bodies = [auth_body] if auth_body
      end
      
    end
  end
end