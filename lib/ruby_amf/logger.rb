require 'active_support'
module RubyAMF
  
  class Logger < ActiveSupport::BufferedLogger
    TIME_FORMAT = '%Y-%m-%d %H:%M:%S %z'
    
    def exception(e)
      backtrace = e.backtrace.is_a?(Array) ? e.backtrace.take(15).join("\n") : e.backtrace
      self.error self.class.colorize("Exception: #{e.message.to_s} (#{e.class.to_s})", 35) + "\n" + backtrace + "\n" + '...'
    end

    class << self
      def colorize(text, color = 36)
        "\e[1m\e[#{color}m#{text}\e[0m"
      end
    end
  end
  
  def RubyAMF.logger
    @logger ||= begin
      log_file = File.open("#{Rails.root}/log/ruby_amf.log", 'a+')
      log_file.sync = true
      buffered_logger = Logger.new(log_file)
      buffered_logger.auto_flushing = 1
      buffered_logger
    end
  end
end