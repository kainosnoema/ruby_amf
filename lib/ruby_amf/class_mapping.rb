module RubyAMF
  # module ClassMapper
  #
  #   this method of mapping classes doesn't work in development mode
  #   because not all AR models are loaded at startup so the mappings
  #   aren't neccessarily instantiated in time for AMF requests
  #   
  #   def self.included(base)
  #     base.extend(ClassMethods)
  #   end
  #   
  #   module ClassMethods
  #     def map_to_actionscript(as_class_name, options = {})
  #       options.merge!({:ruby => self.name, :actionscript => as_class_name})
  #       ClassMapping.define do |m|
  #         m.map options
  #       end
  #     end
  #   end
  #   
  # end
  class ClassMapping
    OBJECT_METHODS = Object.new.public_methods.freeze
    
    @@ignore_attributes = ['id', 'created_at', 'updated_at']
    @@ignore_methods = OBJECT_METHODS
    
    class << self
      
      def define
        yield mappings
      end
      
      def ignore_attributes
        @@ignore_attributes
      end
      
      def ignore_attributes=(value)
        @@ignore_attributes = value.map(&:to_s) if value
      end
      
      def ignore_methods
        @@ignore_methods
      end
      
      def ignore_methods=(value)
        @@ignore_methods = (value + OBJECT_METHODS).uniq
      end
      
      #
      # for deserializing
      #
      
      def ruby_class_name_for(class_name)
        mapping = mappings.mapping_for_as(class_name.to_s)
        mapping.nil? ? nil : mapping.ruby_class_name
      end
      
      def ruby_object_for(as_class_name)
        ruby_class_name = ruby_class_name_for(as_class_name)
        if ruby_class_name.nil?
          TypedHash.new(as_class_name)  # no mapping, populate a hash with an explicit type
        else
          deep_const_get(ruby_class_name).new
        end
      end
      
      def populate_ruby_object(obj, properties, dynamic_props=nil)
        properties.merge!(dynamic_props) if dynamic_props
        hash_like = obj.respond_to?("[]=")
        (properties.keys - @@ignore_attributes).each do |attr_name|
          if obj.respond_to?("#{attr_name}=")
            obj.send("#{attr_name}=", properties[attr_name])
          elsif hash_like
            obj[attr_name] = properties[attr_name]
          end
        end
        obj
      end
      
      #
      # for serializing
      #
      def as_class_name_for(ruby_obj)
        if(ruby_obj.is_a?(Hash))
          ruby_obj[TypedHash::EXPLICIT_TYPE_KEY]
        else
          class_name = case
            when ruby_obj.is_a?(String) then ruby_obj 
            when ruby_obj.is_a?(Class) then ruby_obj.name
            else ruby_obj.class.name
          end
          mapping = mappings.mapping_for_ruby(class_name)
          mapping.nil? ? nil : mapping.as_class_name
        end
      end
      
      def as_traits_for(ruby_obj)
        {:class_name => as_class_name_for(ruby_obj), :members => [], :externalizable => false, :dynamic => true}
      end
      
      def as_properties_for(ruby_obj)
        properties = {}
        if ruby_obj.is_a?(Hash)
          properties = ruby_obj.reject{|k,v| k == TypedHash::EXPLICIT_TYPE_KEY || @@ignore_attributes.include?(k.to_s)}
        
        elsif(ruby_obj.is_a?(ActiveRecord::Base))
          if mapping = mappings.mapping_for_ruby(ruby_obj.class.name)
            # read specified attributes
            (mapping.attributes - @@ignore_attributes).each do |attr_name|
              properties[attr_name] = ruby_obj.read_attribute(attr_name)
            end
            # read loaded associations
            mapping.associations.each do |assoc_name|
              if(ruby_obj.instance_variable_defined?("@#{assoc_name}"))
                association = ruby_obj.instance_variable_get("@#{assoc_name}")
                association = association.to_a if association.respond_to?(:to_a) # convert has_many association to array
                properties[assoc_name] = association
              end
            end
            
          else
            (ruby_obj.attribute_names - @@ignore_attributes).each do |attr_name|
              properties[attr_name] = ruby_obj.read_attribute(attr_name)
            end
          end
          
        else
          RubyAMF.logger.info "serializing custom type: #{ruby_obj.class.to_s}"
          (ruby_obj.public_methods - @@ignore_methods).each do |method_name|
            # add to properties if method takes no arguments
            properties[method_name.to_s] = ruby_obj.send(method_name) if ruby_obj.method(method_name).arity == 0
          end
        end
        properties
      end

      private
      
        def mappings
          @@mappings ||= MappingSet.new
        end
        
        def deep_const_get(ruby_class_name)
          ruby_class_name.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
        end
    end
    
    class MappingSet
      
      attr_accessor :actionscript_namespace,
                    :actionscript_mappings,
                    :ruby_mappings
      
      def initialize
        @actionscript_mappings = {}
        @ruby_mappings = {}
        
        # Map defaults
        map :actionscript => 'flex.messaging.messages.AbstractMessage',     :ruby => 'RubyAMF::Messages::AbstractMessage'
        map :actionscript => 'flex.messaging.messages.RemotingMessage',     :ruby => 'RubyAMF::Messages::RemotingMessage'
        map :actionscript => 'flex.messaging.messages.AsyncMessage',        :ruby => 'RubyAMF::Messages::AsyncMessage'
        map :actionscript => 'flex.messaging.messages.CommandMessage',      :ruby => 'RubyAMF::Messages::CommandMessage'
        map :actionscript => 'flex.messaging.messages.AcknowledgeMessage',  :ruby => 'RubyAMF::Messages::AcknowledgeMessage'
        map :actionscript => 'flex.messaging.messages.ErrorMessage',        :ruby => 'RubyAMF::Messages::ErrorMessage'
      end

      # Maps AS classes to ruby classes.
      # Use fully qualified names for both.
      #
      # For example:
      #   m.map :actionscript => 'com.example.Date', :ruby => 'Example::Date'
      def map(options = {})
        [:actionscript, :ruby].each {|k| options[k] = options[k].to_s if options[k] }
        @actionscript_mappings[options[:actionscript]] = @ruby_mappings[options[:ruby]] = Mapping.new(options)
      end

      def mapping_for_ruby(value)
        @ruby_mappings[value.to_s]
      end

      def mapping_for_as(value)
        @actionscript_mappings[value.to_s]
      end
      
      class Mapping
        @populated = false
        attr_reader :as_class_name,
                    :ruby_class_name,
                    :attributes,
                    :ignore_attributes,
                    :associations
                      
        def initialize(options = {})
          @as_class_name      = options[:actionscript]
          @ruby_class_name    = options[:ruby]
          
          @attributes         = options[:only].map(&:to_s) if options[:only]
          @ignore_attributes  = options[:except].map(&:to_s) if options[:except]
          @associations       = options[:associations].map(&:to_s) if options[:associations]
          
          if @as_class_name.blank? || @ruby_class_name.blank?
            raise StandardError.new("Invalid mapping: missing parameters")
          end
          
          # catching exceptions here will cause backtraces to be useless
          object = @ruby_class_name.constantize.new
          
          if object.is_a?(ActiveRecord::Base)
            @attributes ||= object.class.column_names.to_a
            @attributes -= @ignore_attributes if @ignore_attributes
            @associations ||= object.class.reflect_on_all_associations.map{|a| a.name.to_s }
          end
        end
      end
    end
  end
end