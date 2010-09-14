module RubyAMF
  class ClassMapping

    @@ignored_methods = TypedHash.new.public_methods

    class << self
      
      def define
        yield mappings
      end
      
      def ignored_methods
        @@ignored_methods
      end
      
      def ignored_methods=(value)
        @@ignored_methods = value + TypedHash.new.public_methods
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
          ruby_class = ruby_class_name.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
          ruby_class.new
        end
      end
      
      def populate_ruby_object(obj, properties, dynamic_props=nil)
        properties.merge!(dynamic_props) if dynamic_props
        hash_like = obj.respond_to?("[]=")
        properties.each_pair do |key, value|
          if obj.respond_to?("#{key}=")
            obj.send("#{key}=", value)
          elsif hash_like
            obj[key.to_sym] = value
          end
        end
        obj
      end
      
      #
      # for serializing
      #
      def as_class_name_for(ruby_obj)
        if(ruby_obj.is_a?(TypedHash))
          ruby_obj._explicit_type
        else
          class_name = ruby_obj.is_a?(String) ? ruby_obj : ruby_obj.class.name
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
          properties = ruby_obj
        
        elsif(ruby_obj.is_a?(ActiveRecord::Base))
          if mapping = mappings.mapping_for_ruby(ruby_obj.class.name)
            # read specified attributes
            mapping.attributes.each do |attr_name|
              properties[attr_name] = ruby_obj.read_attribute(name)
            end
            # read loaded associations
            ruby_obj.instance_variables.each do |i_var|
              var_name = i_var.to_s[1..-1]
              if(mapping.associations.include?(var_name))
                properties[var_name] = ruby_obj.instance_variable_get(i_var).try(:to_a)
              end
            end
          else
            ruby_obj.attributes.each do |key, value|
              properties[key] = value
            end
          end
          
        else
          (ruby_obj.public_methods - @@ignored_methods).each do |method_name|
            next if ruby_obj.method(method_name).arity > 0
            # Add them to properties if they take no arguments
            properties[method_name.to_s] = ruby_obj.send(method_name) 
          end
        end
        properties
      end

      private
      
        def mappings
          @mappings ||= MappingSet.new
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
        attr_accessor :as_class_name,
                      :ruby_class_name,
                      :attributes,
                      :associations
                      
        def initialize(options = {})
          @as_class_name      = options[:actionscript]
          @ruby_class_name    = options[:ruby]
          @attributes         = options[:attributes]
          @associations       = options[:associations]
          
          if @as_class_name.blank? || @ruby_class_name.blank?
            raise Exception.new("Invalid mapping: missing mapping parameters")
          end
          
          begin
            object = @ruby_class_name.constantize.new
            if object.is_a?(ActiveRecord::Base)
              @attributes ||= object.class.column_names
              @associations ||= object.class.reflect_on_all_associations.collect{|a| a.name.to_s }
            end
          rescue
            raise Exception.new("Invalid mapping: unable to instantiate #{@ruby_class_name}")
          end
        end    
      end
    end
  end
end