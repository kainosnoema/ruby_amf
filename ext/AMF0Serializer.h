#include "IOWriteBuffer.h"

extern VALUE rb_cRubyAMF_Ext_AMF0Serializer;
extern void write_boolean(buffer_t* buffer, VALUE rval);
extern void write_utf_string(buffer_t* buffer, VALUE rval);
extern void write_amf0(buffer_t* buffer, VALUE rval);

void Init_AMF0Serializer();
