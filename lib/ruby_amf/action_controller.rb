# this extends ActionController::Base to help with rendering and credentials
ActionController::Base.class_eval do
  def render_with_amf(options = nil, &block)
    begin
      if options && options.is_a?(Hash) && options.keys.include?(:amf) && !@performed_render
        #RubyAMF::Configuration::ClassMappings.current_mapping_scope = options[:class_mapping_scope] || RubyAMF::Configuration::ClassMappings.default_mapping_scope

        RubyAMF::Gateway.service_result = options[:amf]  #store results, can't prematurely return or send_data
        @performed_render = true
      else
        render_without_amf(options, &block)
      end
    rescue Exception => e
      raise e if !e.message.match(/^Missing template/) #suppress missing template warnings
    end
  end
  alias_method_chain :render, :amf
end

class ActionController::Base
  attr_accessor :is_amf
  attr_accessor :rubyamf_params # this way we can always access the rubyamf_params
  
#   #Higher level "credentials" method that returns credentials wether or not
#   #it was from setRemoteCredentials, or setCredentials
#   def credentials
#     #return an empty auth, this watches out for being the cause of an exception, (nil[])
#     amf_credentials || html_credentials || {:username => nil, :password => nil}
#   end
#   
# private
#   #setCredentials access
#   def amf_credentials
#     RubyAMF::Gateway.authentication
#   end
#   
#   #remoteObject setRemoteCredentials retrieval
#  def html_credentials
#     auth_data = request.env['RAW_POST_DATA']
#     auth_data = auth_data.scan(/DSRemoteCredentials\006.([A-Za-z0-9\+\/=]*).*?\006/)[0][0]
#     auth_data.gsub!("DSRemoteCredentialsCharset", "")
#     if auth_data.size > 0
# 
#       remote_auth = Base64.decode64(auth_data).split(':')[0..1]
#     else
#       return nil
#     end
#     case RubyAMF::Configuration::ClassMappings.hash_key_access
#     when :string then
#       return {'username' => remote_auth[0], 'password' => remote_auth[1]}
#     when :symbol then
#       return {:username => remote_auth[0], :password => remote_auth[1]}
#     when :indifferent then
#       return HashWithIndifferentAccess.new({:username => remote_auth[0], :password => remote_auth[1]})
#     end
#   end
end