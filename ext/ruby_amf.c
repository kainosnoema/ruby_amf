
#include "ruby.h"
#include "ruby_amf_core.h"
#include "AMF3Serializer.h"
#include "AMF0Deserializer.h"
#include "AMF3Deserializer.h"

void Init_ruby_amf_ext() {
  Init_ruby_amf_core();
  Init_ruby_amf_AMF0Deserializer();
  Init_ruby_amf_AMF3Deserializer();
  Init_ruby_amf_AMF3Serializer();
}
