require 'active_support'
module RubyAMF
  LOG_TIME_FORMAT = '%Y-%m-%d %H:%M:%S %z'
  
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
  
  def RubyAMF.colorize(text, color = 36)
    "\e[1m\e[#{color}m#{text}\e[0m"
  end
end