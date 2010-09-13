# extends ActionController::Base to help with rendering
class ActionController::Base
  attr_accessor :is_amf, :amf_params, :processed_amf
end

ActionController::Base.class_eval do
  
  def process_with_amf(action)
    @processed_amf = nil
    process_without_amf(action)
  end
  alias_method_chain :process, :amf
  
  def render_with_amf(options = nil, &block)
    begin
      if options.is_a?(Hash) && @is_amf && @processed_amf.nil?
        @processed_amf = options.keys.include?(:amf) ? options.delete(:amf) : options  # store results, can't prematurely return or send_data
      end
      render_without_amf(options, &block)
    rescue Exception => e
      raise e if !e.message.match(/^Missing template/) # suppress missing template warnings
    end
  end
  alias_method_chain :render, :amf
  
end
