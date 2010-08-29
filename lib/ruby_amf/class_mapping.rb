module RubyAMF
  class ClassMapping

    @@ignored_instance_vars = TypedHash.new.instance_variables

    class << self
      
      def define
        yield mappings
      end
    
      def actionscript_namespace
        mappings.actionscript_namespace
      end
    
      def actionscript_namespace=(value)
        mappings.actionscript_namespace = value
      end
      
      def ignored_instance_vars
        @@ignored_instance_vars
      end
      
      def ignored_instance_vars=(value)
        @@ignored_instance_vars = value + TypedHash.new.instance_variables
      end
      
      #
      # for deserializing
      #
      
      def ruby_class_name_for(as_class_name)
        mappings.ruby_class_name_for(as_class_name.to_s)
      end
      
      def ruby_object_for(as_class_name)
        ruby_class_name = mappings.ruby_class_name_for(as_class_name)
        if ruby_class_name.nil?
          return TypedHash.new(as_class_name)  # Populate a simple hash, since no mapping
        else
          ruby_class = ruby_class_name.split('::').inject(Kernel) {|scope, const_name| scope.const_get(const_name)}
          return ruby_class.new
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
          as_class_name = ruby_obj._explicit_type
        else
          ruby_class_name = ruby_obj.is_a?(String) ? ruby_obj : ruby_obj.class.name
          as_class_name = mappings.as_class_name_for(ruby_class_name) || ruby_class_name
        end
        as_class_name
      end
      
      def as_properties_for(ruby_obj)
        properties = {}
        instance_vars = ruby_obj.instance_variables - @@ignored_instance_vars
        instance_vars.each do |instance_var|
          attr_name = instance_var.to_s[1..-1]
          properties[attr_name] = ruby_obj.instance_variable_get(instance_var)
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
        map :actionscript => 'flex.messaging.io.ArrayCollection',           :ruby => 'RubyAMF::Messages::ArrayCollection'
      end

      # Maps AS classes to ruby classes.
      # Use fully qualified names for both.
      #
      # For example:
      #   m.map :actionscript => 'com.example.Date', :ruby => 'Example::Date'
      def map(params = {})
        [:actionscript, :ruby].each {|k| params[k] = params[k].to_s if params[k] }
        
        if params.key?(:actionscript) and params.key?(:ruby)
          @actionscript_mappings[params[:actionscript]] = params[:ruby]
          @ruby_mappings[params[:ruby]] = params[:actionscript]
        end
        
        if params.key?(:actionscript)
          params[:ruby] = ruby_class_name_for(params[:actionscript])
        end
      end

      def as_class_name_for(value)
        ruby_class_name = value.to_s
        unless as_class_name = @ruby_mappings[ruby_class_name]
          as_class_name = [@actionscript_namespace, ruby_class_name].reject(&:blank?).join('.')
          @actionscript_mappings[as_class_name] ||= ruby_class_name
          @ruby_mappings[ruby_class_name] ||= as_class_name
        end
        as_class_name
      end

      def ruby_class_name_for(value)
        as_class_name = value.to_s
        unless (ruby_class_name = @actionscript_mappings[as_class_name]) || actionscript_namespace.nil?
          ruby_class_name = class_name.sub("#{actionscript_namespace}.", "")
          @ruby_mappings[ruby_class_name] ||= as_class_name
          @actionscript_mappings[as_class_name] ||= ruby_class_name
        end
        ruby_class_name
      end
    end
  end
end