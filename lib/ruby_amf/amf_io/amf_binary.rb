begin
  module RubyAMF
    module AMFIo
      module Constants
        #AMF0
        AMF_NUMBER = 0x00
        AMF_BOOLEAN = 0x01
        AMF_STRING = 0x02
        AMF_OBJECT = 0x03
        AMF_MOVIE_CLIP = 0x04
        AMF_NULL = 0x05
        AMF_UNDEFINED = 0x06
        AMF_REFERENCE = 0x07
        AMF_MIXED_ARRAY = 0x08
        AMF_EOO = 0x09
        AMF_ARRAY = 0x0A
        AMF_DATE = 0x0B
        AMF_LONG_STRING = 0x0C
        AMF_UNSUPPORTED = 0x0D
        AMF_RECORDSET = 0x0E
        AMF_XML = 0x0F
        AMF_TYPED_OBJECT = 0x10

        #AMF3
        AMF3_TYPE = 0x11
        AMF3_UNDEFINED = 0x00
        AMF3_NULL = 0x01
        AMF3_FALSE = 0x02
        AMF3_TRUE = 0x03
        AMF3_INTEGER = 0x04
        AMF3_NUMBER = 0x05
        AMF3_STRING = 0x06
        AMF3_XML = 0x07
        AMF3_DATE = 0x08
        AMF3_ARRAY = 0x09
        AMF3_OBJECT = 0x0A
        AMF3_XML_STRING = 0x0B
        AMF3_BYTE_ARRAY = 0x0C
        AMF3_INTEGER_MAX = 268435455
        AMF3_INTEGER_MIN = -268435456
      end
      
      module ByteOrder
        #examines the locale byte order on the running machine
        def byte_order
          if [0x12345678].pack("L") == "\x12\x34\x56\x78" 
            :BigEndian
          else
            :LittleEndian
          end
        end
    
        def byte_order_little?
          byte_order == :LittleEndian
        end
      end

      module BinaryReader
        include ByteOrder
        
        #read N length from stream starting at position
        def readn(length)
          self.stream_position ||= 0
          str = self.stream[self.stream_position, length]
          self.stream_position += length
          str
        end
    
        # Aryk: TODO: This needs to be written more cleanly. Using rescue and then regex checks on top of that slows things down
        def read_word8
          begin
            readn(1).unpack('C').first
          #this handles an exception condition when Rails' ActionPack strips off the last "\000" of the AMF stream
          rescue Exception => e
            stream_position += 1
            return 0
          end
        end
    
        #8bits no byte order
        def read_int8
          readn(1).unpack('c').first
        end
        alias :read_byte :read_int8

        def read_word16
          readn(2).unpack('n').first
        end
        
        def read_int16
          str = readn(2)
          str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
          str.unpack('s').first
        end
    
        def read_word32
          readn(4).unpack('N').first
        end

        def read_int32
          str = readn(4)
          str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
          str.unpack('l').first
        end
    
        def read_double
          readn(8).unpack('G').first
        end
    
        #read utility methods
        def read_boolean
          read_int8 == 1
        end
        
        def read_utf
          length = read_word16
          readn(length)
        end
    
        def read_long_utf(length)
          length = read_word32
          readn(length)
        end
      end

      module BinaryWriter
        include ByteOrder
      
        def writen(val)
          @stream << val
        end
    
        #8 bit no byteorder
        def write_word8(val)
         writen [val].pack('C')
        end

        def write_int8(val)
          writen [val].pack('c')
        end
        alias :write_byte :write_int8
    
        def write_word16(val)
          str = [val].pack('S')
          str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
          writen str
        end
        
        def write_int16(val)
          writen [val].pack('n')
        end

        def write_word32(val)
          str = [val].pack('L')
          str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
          writen str
        end

        def write_int32(val)
          writen [val].pack('N')
        end
    
        # write utility methods
        def write_boolean(val)
          if val then self.write_byte(1) else self.write_byte(0) end
        end

        def write_utf(str)
          write_int16(str.length)
          writen str
        end
    
        def write_long_utf(str)
          write_int32(str.length)
          writen str
        end
      
        def write_double(val)
          writen ( @floats_cache[val] ||= 
            [val].pack('G')
          )
        end
      end
    end
  end
rescue Exception => e
  raise RUBYAMFException.new(RUBYAMFException.AMF_ERROR, "The AMF data is incorrect or incomplete.")
end
