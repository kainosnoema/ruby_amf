# a simple wrapper class that wraps an amfheader

module RubyAMF
  module AMF
    class AMFHeader
      attr_accessor :name, :value, :required
      
      def initialize(name, required, value)
        @name, @value, @required = name, value, required
      end
      
    end 
  end
end