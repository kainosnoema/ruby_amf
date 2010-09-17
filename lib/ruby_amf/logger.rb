require 'active_support'
module RubyAMF
  def RubyAMF.logger
    @ruby_amf_logger ||= begin
      log_file = File.open("#{Rails.root}/log/ruby_amf.log", 'a+')
      log_file.sync = true
      buffered_logger = ActiveSupport::BufferedLogger.new(log_file)
      buffered_logger.auto_flushing = 1
      buffered_logger
    end
  end
  
  def RubyAMF.log_exception(e)
    RubyAMF.logger.error e.to_s + "\n" + e.backtrace.take(15).join("\n") + "\n" + '...'
  end
end