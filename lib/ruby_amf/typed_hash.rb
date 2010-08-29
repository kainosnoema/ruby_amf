module RubyAMF
  class TypedHash < Hash
    attr_accessor :_explicit_type

    def initialize(type = nil)
      self._explicit_type ||= type
    end
    
    def ==(other)
      other.is_a?(TypedHash) && self._explicit_type == other._explicit_type && super
    end
  end
end