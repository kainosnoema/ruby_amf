#include "IOReadBuffer.h"

extern VALUE rb_cRubyAMF_Ext_AMF0Deserializer;
extern VALUE rb_read_boolean(load_context_t* context);
extern VALUE rb_read_utf_string(load_context_t* context);
extern VALUE rb_read_amf0(load_context_t* context, uint8_t type);

void Init_AMF0Deserializer();

