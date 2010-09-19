module RubyAMF
  class TypedHash < Hash
    EXPLICIT_TYPE_KEY = '_explicit_as_type'

    def initialize(type = nil)
      self[self.class::EXPLICIT_TYPE_KEY] ||= type if type.present?
    end
    
    def ==(other)
      other.is_a?(TypedHash) && self[self.class::EXPLICIT_TYPE_KEY] == other[self.class::EXPLICIT_TYPE_KEY] && super
    end
  end
end