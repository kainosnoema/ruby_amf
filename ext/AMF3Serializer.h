#include "IOWriteBuffer.h"

extern VALUE rb_cRubyAMF_Ext_AMF3Serializer;
extern void write_amf3(buffer_t* buffer, VALUE object);

void Init_AMF3Serializer();
