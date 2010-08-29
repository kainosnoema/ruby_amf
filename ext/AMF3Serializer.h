#include "IOWriteBuffer.h"

#define bool uint8_t

extern VALUE rb_cRubyAMF_Ext_AMF3Serializer;
extern void write_amf3(buffer_t* buffer, VALUE object);

void Init_ruby_amf_AMF3Serializer();
