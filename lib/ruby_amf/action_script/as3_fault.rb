#ActionScript 3 Exeption, this class bubbles to the player after an Exception in Ruby

module RubyAMF
  module ActionScript
    class AS3Fault < RubyAMF::VoHelper::VoHash

      #pass a RUBYAMFException, create new keys based on exception for the fault object
      def initialize(e)
        backtrace = e.backtrace || e.ebacktrace #grab the correct backtrace    
        self._explicitType = 'flex.messaging.messages.ErrorMessage'
        self["faultCode"] = e.etype.to_s #e.type.to_s
        self["faultString"] = e.message
        self["faultDetail"] = backtrace
        self["rootCause"] = backtrace[0]
        self["extendedData"] = e.payload || backtrace
      end
      
    end
  end
end