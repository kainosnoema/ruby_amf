
#include <string.h>
#include <math.h>
#include "ruby_amf_core.h"
#include "IOWriteBuffer.h"
#include "AMFConstants.h"
#include "AMFCache.h"

VALUE rb_cRubyAMF_Ext_AMF3Serializer = Qnil;

void write_amf3(buffer_t* buffer, VALUE rval);
static VALUE t_serialize(VALUE self, VALUE string);

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

void write_amf3_reference(buffer_t* buffer, uint32_t i)
{
  write_c_integer(buffer, i << 1);
}

int write_objref_if_exists(buffer_t* buffer, VALUE rval)
{
  VALUE ref = amf_cache_get_objref(buffer->amf_cache, rval);
  if(ref != Qnil)
  {
    write_amf3_reference(buffer, (uint32_t)FIX2LONG(ref));
    return 1;
  }
  else
  {
    amf_cache_add_objref(buffer->amf_cache, rval);
    return 0;
  }
}

void write_amf3_string(buffer_t* buffer, VALUE rval)
{
  if(rb_type(rval) != T_STRING)
    rval = rb_funcall(rval, rb_intern("to_s"), 0);
  
  if(rval == Qnil || RSTRING_LEN(rval) == 0) {
    write_c_int8(buffer, AMF3_EMPTY_STRING);
    return;
  }
  
  rval = rb_funcall(rval, rb_intern("encode"), 1, rb_str_new2("UTF-8"));
  rval = rb_funcall(rval, rb_intern("force_encoding"), 1, rb_str_new2("ASCII-8BIT"));
  
  VALUE ref = amf_cache_get_stringref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_amf3_reference(buffer, (uint32_t)FIX2LONG(ref));
  else
  {
   amf_cache_add_stringref(buffer->amf_cache, rval);
    
    uint32_t len = (uint32_t)RSTRING_LEN(rval);
    uint32_t header = len << 1 | 1;
    write_c_integer(buffer, header);
    write_bytes(buffer, (u_char *)RSTRING_PTR(rval), len);
  }
}

void write_amf3_time(buffer_t* buffer, VALUE rval)
{
  if(write_objref_if_exists(buffer, rval))
    return;
    
  rval = rb_funcall(rval, rb_intern("getutc"), 0);
  double milleseconds = NUM2DBL(rb_funcall(rval, rb_intern("to_f"), 0)) * 1000;
  
  write_c_int8(buffer, AMF3_NULL);
  write_c_double(buffer, trunc(milleseconds + 0.5));
}

void write_amf3_date(buffer_t* buffer, VALUE rval)
{
  if(write_objref_if_exists(buffer, rval))
    return;
    
  rval = rb_funcall(rval, rb_intern("strftime"), 1, rb_str_new2("%s"));
  double milleseconds = NUM2DBL(rb_funcall(rval, rb_intern("to_i"), 0)) * 1000;
  
  write_c_int8(buffer, AMF3_NULL);
  write_c_double(buffer, trunc(milleseconds + 0.5));
}

void write_amf3_array(buffer_t* buffer, VALUE rval)
{
  if(write_objref_if_exists(buffer, rval))
    return;
    
  uint32_t len = (uint32_t)RARRAY_LEN(rval);
  uint32_t header = len << 1 | 1;
  write_c_integer(buffer, header);
  write_c_int8(buffer, AMF3_CLOSE_DYNAMIC_ARRAY);
  uint32_t i = 0;
  for (;i<len;i++) {
    write_amf3(buffer, RARRAY_PTR(rval)[i]);
  }
}

VALUE write_amf3_hash_pair(VALUE values, buffer_t * buffer, int argc, VALUE *argv)
{ 
  VALUE key = RARRAY_PTR(values)[0];
  VALUE value = RARRAY_PTR(values)[1];
  
  if(rb_type(key) == T_SYMBOL)
    key = rb_str_new2(rb_id2name(SYM2ID(key)));
  
  write_amf3_string(buffer, key);
  write_amf3(buffer, value);

  return Qnil;
}

void write_amf3_object(buffer_t* buffer, VALUE rval)
{
  if(write_objref_if_exists(buffer, rval))
    return;

  write_c_int8(buffer, AMF3_DYNAMIC_OBJECT);
  
  VALUE class_name = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_class_name_for"), 1, rval);
  if(class_name != Qnil)
    write_amf3_string(buffer, class_name);
  else
    write_c_int8(buffer, AMF3_ANONYMOUS_OBJECT);
    
  VALUE properties = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_properties_for"), 1, rval);
  rb_block_call(properties, rb_intern("each"), 0, 0, write_amf3_hash_pair, (VALUE)buffer);

  write_c_int8(buffer, AMF3_CLOSE_DYNAMIC_OBJECT);
}

void write_amf3(buffer_t* buffer, VALUE rval)
{
  switch(rb_type(rval)) {
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
      write_c_int8(buffer, AMF3_DOUBLE);
      write_c_double(buffer, NUM2DBL(rval));
      break;
    }
    case T_FIXNUM: {
      double c_double = NUM2DBL(rval);
      if(c_double >= MIN_AMF3_INTEGER && c_double <= MAX_AMF3_INTEGER) // check valid range for 29bits
      {
        write_c_int8(buffer, AMF3_INTEGER);
        write_c_integer(buffer, (int32_t)NUM2LONG(rval));
      }
      else
      {
        write_c_int8(buffer, AMF3_DOUBLE);
        write_c_double(buffer, NUM2DBL(rval));
      }
      break;
    }
    case T_FLOAT: {
      write_c_int8(buffer, AMF3_DOUBLE);
      write_c_double(buffer, NUM2DBL(rval));
      break;
    }
    case T_STRING: {
      write_c_int8(buffer, AMF3_STRING);
      write_amf3_string(buffer, rval);
      break;
    }
    case T_SYMBOL: {
      write_c_int8(buffer, AMF3_STRING);
      write_amf3_string(buffer, rb_str_new2(rb_id2name(SYM2ID(rval))));
      break;
    }
    case T_ARRAY: {
      write_c_int8(buffer, AMF3_ARRAY);
      write_amf3_array(buffer, rval);
      break;
    }
    case T_HASH: {
      write_c_int8(buffer, AMF3_OBJECT);
      write_amf3_object(buffer, rval);
      break;
    }
    case T_DATA:
    case T_OBJECT: {
      const char* cls = rb_obj_classname(rval);
      if(strcmp(cls, "Time") == 0 || strcmp(cls, "DateTime") == 0 || strcmp(cls, "ActiveSupport::TimeWithZone") == 0)
      {
        write_c_int8(buffer, AMF3_DATE);
        write_amf3_time(buffer, rval);
        break;
      }
      if(strcmp(cls, "Date") == 0)
      {
        write_c_int8(buffer, AMF3_DATE);
        write_amf3_date(buffer, rval);
        break;
      }
      if(strcmp(cls, "BigDecimal") == 0)
      {
        write_c_int8(buffer, AMF3_DOUBLE);
        write_c_double(buffer, NUM2DBL(rb_funcall(rval, rb_intern("to_f"), 0)));
        break;
      }

      write_c_int8(buffer, AMF3_OBJECT);
      write_amf3_object(buffer, rval);
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

static VALUE t_serialize(VALUE self, VALUE rval)
{
  buffer_t * buffer = buffer_new();
  write_amf3(buffer, rval);
  return buffer_to_rstring(buffer);
}

void Init_AMF3Serializer() {
  rb_cRubyAMF_Ext_AMF3Serializer = rb_define_class_under(rb_mRubyAMF_Ext, "AMF3Serializer", rb_cObject);
  rb_define_method(rb_cRubyAMF_Ext_AMF3Serializer, "serialize", t_serialize, 1);
}