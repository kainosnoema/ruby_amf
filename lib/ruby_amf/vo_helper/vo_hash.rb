module RubyAMF
  module VoHelper
    class VoHash < Hash
      attr_accessor :_explicitType
      def ==(other)
        other.is_a?(VoHash) && !_explicitType.nil? && _explicitType == other._explicitType && super
      end
    end
  end
end
