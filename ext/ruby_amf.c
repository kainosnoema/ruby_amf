
#include "ruby.h"
#include "ruby_amf_core.h"
#include "AMF0Serializer.h"
#include "AMF3Serializer.h"
#include "AMF0Deserializer.h"
#include "AMF3Deserializer.h"
#include "AMFRemoting.h"

void Init_ruby_amf_ext() {
  Init_ruby_amf_core();
  
  Init_AMF0Deserializer();
  Init_AMF3Deserializer();

  Init_AMF0Serializer();
  Init_AMF3Serializer();
  
  // adds a method to RubyAMF::Remoting::Envelope
  Init_AMFRemoting();
}
