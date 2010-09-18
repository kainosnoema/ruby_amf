module RubyAMF
  class Person
    attr_accessor :name, :age, :gender
    attr_accessor :occupation

    # amf \
    #   :class   => 'be.mrhenry.contacts.Person',
    #   :static  => %w( @name age gender ),
    #   :ignore  => %w( age_in_seconds )
  end

  class Card
    attr_accessor :phone_numbers
  
    def initialize(*numbers)
      @phone_numbers = numbers
    end
  
    # amf \
    #   :class   => 'be.mrhenry.contacts.Card',
    #   :static  => %w( @phone_numbers ),
    #   :dynamic => false
  end

  class PhoneNumber
    attr_accessor :value, :label
  
    def initialize(value, label=nil)
      @value = value
      @label = label if label
    end
  
    # amf \
    #   :class   => 'be.mrhenry.contacts.PhoneNumber',
    #   :static  => %w( @value ),
    #   :dynamic => true
  end
  
  ClassMapping.define do |m|
    m.map :actionscript => 'com.ekulnave.contacts.Person', :ruby => 'RubyAMF::Person'
  end
end