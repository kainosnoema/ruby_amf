#include "IOReadBuffer.h"

#define bool uint8_t

extern VALUE rb_mRubyAMF_Ext_AMF3Deserializer;
extern VALUE rb_read_amf3(load_context_t* context);

void Init_ruby_amf_AMF3Deserializer();
