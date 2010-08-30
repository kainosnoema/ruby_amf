
#include <string.h>
#include <math.h>
#include "ruby_amf_core.h"
#include "IOWriteBuffer.h"
#include "AMFConstants.h"
#include "AMF3Serializer.h"
#include "AMFCache.h"

VALUE rb_cRubyAMF_Ext_AMF0Serializer = Qnil;

void write_amf0(buffer_t* buffer, VALUE object);
static VALUE t_serialize(VALUE self, VALUE string);

void write_boolean(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF0_BOOLEAN);
  write_c_int8(buffer, rval == Qtrue ? 1 : 0);
}

void write_amf0_number(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF0_NUMBER);
  write_c_double(buffer, NUM2DBL(rval));
}

void write_utf_string(buffer_t* buffer, VALUE rval)
{
  uint32_t len = RSTRING_LEN(rval);
  write_c_word16_network(buffer, len);
  write_bytes(buffer, (u_char *)RSTRING_PTR(rval), RSTRING_LEN(rval));
}

void write_utf_long_string(buffer_t* buffer, VALUE rval)
{
  uint32_t len = RSTRING_LEN(rval);
  write_c_word32_network(buffer, len);
  write_bytes(buffer, (u_char *)RSTRING_PTR(rval), len);
}

void write_amf0_string(buffer_t* buffer, VALUE rval)
{
  if(RSTRING_LEN(rval) < 2^16-1)
  {
    write_c_int8(buffer, AMF0_STRING);
    write_utf_string(buffer, rval);
  }
  else
  {
    write_c_int8(buffer, AMF0_LONG_STRING);
    write_utf_long_string(buffer, rval);
  }
}

void write_amf0_date(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF0_DATE);
    
  double milleseconds;
  if(rb_class_of(rval) == rb_cDate)
  {
    rval = rb_funcall(rval, rb_intern("strftime"), 1, rb_str_new2("%s"));
    milleseconds = NUM2DBL(rb_funcall(rval, rb_intern("to_i"), 0)) * 1000;
  }
  else
  {
    rb_funcall(rval, rb_intern("utc"), 0);
    milleseconds = NUM2DBL(rb_funcall(rval, rb_intern("to_f"), 0)) * 1000;
  }

  write_c_double(buffer, trunc(milleseconds + 0.5));
  
  write_c_int16_network(buffer, 0);
}

void write_amf0_array(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF0_STRICT_ARRAY);
  uint16_t i, len = FIX2INT(rb_funcall(rval, rb_intern("length"), 0));
  write_c_word32_network(buffer, len);
  for (i=0; i<len; i++) {
    write_amf0(buffer, rb_ary_entry(rval, i));
  }
}

VALUE write_amf0_hash_pair(VALUE values, buffer_t * buffer, int argc, VALUE *argv)
{ 
  VALUE key = RARRAY_PTR(values)[0];
  VALUE value = RARRAY_PTR(values)[1];
  
  if(TYPE(key) == T_SYMBOL)
    key = rb_str_new2(rb_id2name(SYM2ID(key)));
  
  write_utf_string(buffer, key);
  write_amf0(buffer, value);

  return Qnil;
}

void write_amf0_hash(buffer_t* buffer, VALUE rval)
{
  write_c_int8(buffer, AMF0_HASH);
  
  write_c_word32_network(buffer, FIX2INT(rb_funcall(rval, rb_intern("length"), 0)));
  rb_block_call(rval, rb_intern("each_pair"), 0, 0, write_amf0_hash_pair, (VALUE) buffer);
  
  write_c_int16_network(buffer, 0);
  write_c_int8(buffer, AMF0_OBJECT_END);
}

void write_amf0_object(buffer_t* buffer, VALUE rval)
{
  VALUE class_name = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_class_name_for"), 1, rval);
  
  if(class_name != Qnil) // typed object
  {
    write_c_int8(buffer, AMF0_TYPED_OBJECT);
    write_utf_string(buffer, class_name);
  }
  else // anonymous object
  {
    write_c_int8(buffer, AMF0_OBJECT);
  }
  
  VALUE properties = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_properties_for"), 1, rval);
  rb_block_call(properties, rb_intern("each_pair"), 0, 0, write_amf0_hash_pair, (VALUE) buffer);

  write_c_int16_network(buffer, 0);
  write_c_int8(buffer, AMF0_OBJECT_END);
}

void write_amf0(buffer_t* buffer, VALUE rval)
{
  switch(TYPE(rval)) {
    case T_NIL: {
      write_c_int8(buffer, AMF0_NULL);
      break;
    }
    case T_TRUE:
    case T_FALSE: {
      write_boolean(buffer, rval);
      break;
    }
    case T_BIGNUM:
    case T_FIXNUM:
    case T_FLOAT: {
      write_amf0_number(buffer, rval);
      break;
    }
    case T_STRING: {
      write_amf0_string(buffer, rval);
      break;
    }
    case T_SYMBOL: {
      write_amf0_string(buffer, rb_str_new2(rb_id2name(SYM2ID(rval))));
      break;
    }
    case T_ARRAY: {
      write_amf0_array(buffer, rval);
      break;
    }
    case T_HASH: {
      write_amf0_hash(buffer, rval); // should serialize as object like amf3?
      break;
    }
    case T_OBJECT: {
      if(rb_is_a(rval, rb_cDate))
      {
        write_amf0_date(buffer, rval);
      }
      else
      {
        write_amf0_object(buffer, rval);
      }
      break;
    }
    case T_DATA: {
      if(rb_is_a(rval, rb_cTime))
      {
        write_amf0_date(buffer, rval);
      }
      else
      {
        write_amf0_object(buffer, rval);
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


static VALUE t_serialize(VALUE self, VALUE object)
{
  buffer_t * buffer = buffer_new();
  write_amf0(buffer, object);
  return buffer_to_rstring(buffer);
}

void Init_AMF0Serializer() {
  rb_cRubyAMF_Ext_AMF0Serializer = rb_define_class_under(rb_mRubyAMF_Ext, "AMF0Serializer", rb_cObject);
  rb_define_method(rb_cRubyAMF_Ext_AMF0Serializer, "serialize", t_serialize, 1);
}