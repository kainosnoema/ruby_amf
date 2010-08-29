
#include <string.h>
#include <math.h>
#include "ruby_amf_core.h"
#include "IOWriteBuffer.h"
#include "AMFConstants.h"
#include "AMFCache.h"

VALUE rb_cRubyAMF_Ext_AMF3Serializer = Qnil;

void write_amf3(buffer_t* buffer, VALUE object);
VALUE t_serialize(VALUE self, VALUE string);

void Init_ruby_amf_AMF3Serializer() {
  rb_cRubyAMF_Ext_AMF3Serializer = rb_define_class_under(rb_mRubyAMF_Ext, "AMF3Serializer", rb_cObject);
  rb_define_method(rb_cRubyAMF_Ext_AMF3Serializer, "serialize", t_serialize, 1);
}

void write_c_integer(buffer_t* buffer, int32_t i)
{
  i = i & 0x1fffffff;
  if (i < 0x80) {
    write_c_int8(buffer, i);
  } else if (i < 0x4000) {
    write_c_int8(buffer, ((i >> 7) & 0x7f) | 0x80);
    write_c_int8(buffer, i & 0x7f);
  } else if (i < 0x200000) {
    write_c_int8(buffer, ((i >> 14) & 0x7f) | 0x80);
    write_c_int8(buffer, ((i >>  7) & 0x7f) | 0x80);
    write_c_int8(buffer, i & 0x7f);
  } else {
    write_c_int8(buffer, ((i >> 22) & 0x7f) | 0x80);
    write_c_int8(buffer, ((i >> 15) & 0x7f) | 0x80);
    write_c_int8(buffer, ((i >>  8) & 0x7f) | 0x80);
    write_c_int8(buffer, i & 0xff);
  }
}

void write_reference(buffer_t* buffer, int32_t i)
{
  write_c_integer(buffer, i << 1);
}

void write_integer(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF3_INTEGER);
  write_c_integer(buffer, NUM2LONG(rval));
}

void write_double(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF3_DOUBLE);
  write_c_double(buffer, NUM2DBL(rval));
}

void write_number(buffer_t* buffer, VALUE rval)
{
  double c_double = NUM2DBL(rval);
  if(c_double >= MIN_AMF3_INTEGER && c_double <= MAX_AMF3_INTEGER) // check valid range for 29bits
    write_integer(buffer, rval);
  else
    write_double(buffer, rval);
}

void write_c_string(buffer_t* buffer, char* string)
{
  int32_t len = strlen(string);
  int32_t header = len << 1 | 1;
  write_c_integer(buffer, header);
  write_bytes(buffer, (u_char *)string, len);
}

void write_utf_string(buffer_t* buffer, VALUE rval)
{
  if(RSTRING_LEN(rval) == 0) {
    write_c_int8(buffer, AMF3_EMPTY_STRING);
    return;
  }
  
  int32_t ref = amf_cache_get_stringref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_reference(buffer, ref);
  else
  {
    amf_cache_add_stringref(buffer->amf_cache, rval);
    write_c_string(buffer, (char *)RSTRING_PTR(rval));
  }
}

void write_string(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF3_STRING);
  write_utf_string(buffer, rval);
}

void write_date(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF3_DATE);
  int32_t ref = amf_cache_get_objref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_reference(buffer, ref);
  else
  {
    amf_cache_add_objref(buffer->amf_cache, rval);
    
    double milleseconds;
    if(rb_class_of(rval) == rb_cDate)
    {
      rval = rb_funcall(rval, rb_intern("strftime"), 1, rb_str_new2("%s"));
      milleseconds = NUM2DBL(rb_funcall(rval, rb_intern("to_i"), 0)) * 1000;
    }
    else
    {
      milleseconds = NUM2DBL(rb_funcall(rval, rb_intern("to_f"), 0)) * 1000;
    }
    
    write_c_int8(buffer, AMF3_NULL);
    write_c_double(buffer, trunc(milleseconds + 0.5));
  }
}

void write_array(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF3_ARRAY);
  int32_t ref = amf_cache_get_objref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_reference(buffer, ref);
  else
  {
    amf_cache_add_objref(buffer->amf_cache, rval);
    
    int32_t len = RARRAY_LEN(rval);
    int32_t header = len << 1 | 1;
    write_c_integer(buffer, header);
    write_c_int8(buffer, AMF3_CLOSE_DYNAMIC_ARRAY);
    int32_t i = 0;
    for (;i<len;i++) {
      write_amf3(buffer, RARRAY_PTR(rval)[i]);
    }
  }
}

VALUE write_hash_pair(VALUE values, buffer_t * buffer, int argc, VALUE *argv)
{ 
  VALUE key = RARRAY_PTR(values)[0];
  VALUE value = RARRAY_PTR(values)[1];
  
  if(TYPE(key) == T_SYMBOL)
    key = rb_str_new2(rb_id2name(SYM2ID(key)));
  
  write_utf_string(buffer, key);
  write_amf3(buffer, value);

  return Qnil;
}

void write_object(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF3_OBJECT);
  int32_t ref = amf_cache_get_objref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_reference(buffer, ref);
  else
  {
    amf_cache_add_objref(buffer->amf_cache, rval);
    
    write_c_int8(buffer, AMF3_DYNAMIC_OBJECT); // always serialize as dynamic objects
    
    if(rb_instance_of(rval, rb_cHash))
    {
      write_c_int8(buffer, AMF3_ANONYMOUS_OBJECT);
      rb_block_call(rval, rb_intern("each"), 0, 0, write_hash_pair, (VALUE) buffer);
    }
    else
    {
      VALUE class_name = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_class_name_for"), 1, rval);
      
      if(class_name != Qnil) // typed object
      {
        write_utf_string(buffer, class_name);
      }
      else // anonymous object
      {
        write_c_int8(buffer, AMF3_ANONYMOUS_OBJECT);
      }
      
      VALUE properties = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_properties_for"), 1, rval);
      rb_block_call(properties, rb_intern("each"), 0, 0, write_hash_pair, (VALUE) buffer);
    }

    write_c_int8(buffer, AMF3_CLOSE_DYNAMIC_OBJECT);
  }
}

void write_amf3(buffer_t* buffer, VALUE value)
{
  switch(TYPE(value)) {
    case T_NIL: {
      write_c_int8(buffer, AMF3_NULL);
      break;
    }
    case T_TRUE: {
      write_c_int8(buffer, AMF3_TRUE);
      break;
    }
    case T_FALSE: {
      write_c_int8(buffer, AMF3_FALSE);
      break;
    }
    case T_BIGNUM: {
      write_double(buffer, value);
      break;
    }
    case T_FIXNUM: {
      write_number(buffer, value);
      break;
    }
    case T_FLOAT: {
      write_double(buffer, value);
      break;
    }
    case T_STRING: {
      write_string(buffer, value);
      break;
    }
    case T_SYMBOL: {
      write_string(buffer, rb_str_new2(rb_id2name(SYM2ID(value))));
      break;
    }
    case T_ARRAY: {
      write_array(buffer, value);
      break;
    }
    case T_HASH: {
      write_object(buffer, value);
      break;
    }
    case T_OBJECT: {
      if(rb_is_a(value, rb_cDate))
      {
        write_date(buffer, value);
      }
      else
      {
        write_object(buffer, value);
      }
      break;
    }
    case T_DATA: {
      if(rb_is_a(value, rb_cTime))
      {
        write_date(buffer, value);
      }
      else
      {
        write_object(buffer, value);
      }
      break;
    }
    case T_REGEXP: {
      break;
    }
    default: {
      break;
    }
  }
}

VALUE t_serialize(VALUE self, VALUE object)
{
  buffer_t * buffer = buffer_new();
  write_amf3(buffer, object);
  return buffer_to_rstring(buffer);
}