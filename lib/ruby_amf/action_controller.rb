# extends ActionController::Base to help with rendering
class ActionController::Base
  attr_accessor :is_amf
  attr_accessor :rendered_amf
end

ActionController::Base.class_eval do
  
  def process_as_amf(action)
    self.is_amf = true # set conditional helper
    process(action)
    self.is_amf = false # unset conditional helper
  end
  
  def render_with_amf(options = nil, &block)
    begin
      if options && options.is_a?(Hash) && options.keys.include?(:amf) && !@performed_render
        self.rendered_amf = options[:amf]  #store results, can't prematurely return or send_data
        @performed_render = true
      else
        render_without_amf(options, &block)
      end
    rescue Exception => e
      raise e if !e.message.match(/^Missing template/) # suppress missing template warnings
    end
  end
  alias_method_chain :render, :amf
  
end
