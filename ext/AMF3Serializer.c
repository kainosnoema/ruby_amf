
#include <string.h>
#include <math.h>
#include "ruby_amf_core.h"
#include "IOWriteBuffer.h"
#include "AMFConstants.h"
#include "AMFCache.h"

VALUE rb_cRubyAMF_Ext_AMF3Serializer = Qnil;

void write_amf3(buffer_t* buffer, VALUE object);
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

void write_amf3_reference(buffer_t* buffer, int32_t i)
{
  write_c_integer(buffer, i << 1);
}

void write_amf3_string(buffer_t* buffer, VALUE rval)
{
  if(rval == Qnil || RSTRING_LEN(rval) == 0) {
    write_c_int8(buffer, AMF3_EMPTY_STRING);
    return;
  }
  
  int32_t ref = amf_cache_get_stringref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_amf3_reference(buffer, ref);
  else
  {
    amf_cache_add_stringref(buffer->amf_cache, rval);
    
    int32_t len = RSTRING_LEN(rval);
    int32_t header = len << 1 | 1;
    write_c_integer(buffer, header);
    write_bytes(buffer, (u_char *)RSTRING_PTR(rval), len);
  }
}

void write_amf3_date(buffer_t* buffer, VALUE rval)
{
  int32_t ref = amf_cache_get_objref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_amf3_reference(buffer, ref);
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
      rb_funcall(rval, rb_intern("utc"), 0);
      milleseconds = NUM2DBL(rb_funcall(rval, rb_intern("to_f"), 0)) * 1000;
    }
    
    write_c_int8(buffer, AMF3_NULL);
    write_c_double(buffer, trunc(milleseconds + 0.5));
  }
}

void write_amf3_array(buffer_t* buffer, VALUE rval)
{
  int32_t ref = amf_cache_get_objref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_amf3_reference(buffer, ref);
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

VALUE write_amf3_hash_pair(VALUE values, buffer_t * buffer, int argc, VALUE *argv)
{ 
  VALUE key = RARRAY_PTR(values)[0];
  VALUE value = RARRAY_PTR(values)[1];
  
  if(TYPE(key) == T_SYMBOL)
    key = rb_str_new2(rb_id2name(SYM2ID(key)));
  
  write_amf3_string(buffer, key);
  write_amf3(buffer, value);

  return Qnil;
}

void write_amf3_object(buffer_t* buffer, VALUE rval)
{
  int32_t ref = amf_cache_get_objref(buffer->amf_cache, rval);
  if(ref != Qnil)
    write_amf3_reference(buffer, ref);
  else
  {
    amf_cache_add_objref(buffer->amf_cache, rval);

    VALUE traits             = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_traits_for"), 1, rval);
    rb_gc_register_address(&traits);
    
    VALUE class_name         = rb_hash_aref(traits, ID2SYM(rb_intern("class_name")));
    VALUE members            = rb_hash_aref(traits, ID2SYM(rb_intern("members")));
    uint8_t externalizable   = rb_hash_aref(traits, ID2SYM(rb_intern("externalizable"))) == Qtrue;
    uint8_t dynamic          = rb_hash_aref(traits, ID2SYM(rb_intern("dynamic")))        == Qtrue;
    int32_t member_count     = RARRAY_LEN(members);
  
    int32_t class_ref = amf_cache_get_traitref(buffer->amf_cache, class_name);
    if(class_ref != Qnil)
    {
      write_c_integer(buffer, class_ref << 2 | 0x01);
    }
    else
    {
      if(class_name != Qnil)
      {
        amf_cache_add_traitref(buffer->amf_cache, class_name);
      }

      // write header
      int32_t header = 0x03;
      if(dynamic) {
        header = header | 0x02 << 2;
      }
      if(externalizable) {
        header = header | 0x01 << 2;
      }
      header = header | member_count << 4;
      write_c_integer(buffer, header);
    
      // write class_name
      write_amf3_string(buffer, class_name);
    
      // write out members
      int32_t i;
      for(i=0; i<member_count; i++)
      {
        write_amf3_string(buffer, RARRAY_PTR(members)[i]);
      }
    }

    if(externalizable)
    {
      // write_amf3(buffer, rb_funcall(rval, rb_intern("externalized_data"), 0));
      // return;
    }
    
    // write out sealed properties
    VALUE properties = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_properties_for"), 1, rval);
    int32_t i;
    for(i=0; i<member_count; i++)
    {
      VALUE member = RARRAY_PTR(members)[i];
      write_amf3(buffer, rb_hash_aref(properties, member));
      rb_funcall(properties, rb_intern("delete"), 1, member);
    }
    
    if(dynamic)
    {
      rb_block_call(properties, rb_intern("each_pair"), 0, 0, write_amf3_hash_pair, (VALUE) buffer);
      write_c_int8(buffer, AMF3_CLOSE_DYNAMIC_OBJECT);
    }
    
    rb_gc_unregister_address(&traits);
  }
}

void write_amf3(buffer_t* buffer, VALUE object)
{
  switch(TYPE(object)) {
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
      write_c_double(buffer, NUM2DBL(object));
      break;
    }
    case T_FIXNUM: {
      double c_double = NUM2DBL(object);
      if(c_double >= MIN_AMF3_INTEGER && c_double <= MAX_AMF3_INTEGER) // check valid range for 29bits
      {
        write_c_int8(buffer, AMF3_INTEGER);
        write_c_integer(buffer, NUM2LONG(object));
      }
      else
      {
        write_c_int8(buffer, AMF3_DOUBLE);
        write_c_double(buffer, NUM2DBL(object));
      }
      break;
    }
    case T_FLOAT: {
      write_c_int8(buffer, AMF3_DOUBLE);
      write_c_double(buffer, NUM2DBL(object));
      break;
    }
    case T_STRING: {
      write_c_int8(buffer, AMF3_STRING);
      write_amf3_string(buffer, object);
      break;
    }
    case T_SYMBOL: {
      write_c_int8(buffer, AMF3_STRING);
      write_amf3_string(buffer, rb_str_new2(rb_id2name(SYM2ID(object))));
      break;
    }
    case T_ARRAY: {
      write_c_int8(buffer, AMF3_ARRAY);
      write_amf3_array(buffer, object);
      break;
    }
    case T_HASH: {
      write_c_int8(buffer, AMF3_OBJECT);
      write_amf3_object(buffer, object);
      break;
    }
    case T_OBJECT: {
      if(rb_is_a(object, rb_cDate))
      {
        write_c_int8(buffer, AMF3_DATE);
        write_amf3_date(buffer, object);
      }
      else
      {
        write_c_int8(buffer, AMF3_OBJECT);
        write_amf3_object(buffer, object);
      }
      break;
    }
    case T_DATA: {
      if(rb_is_a(object, rb_cTime))
      {
        write_c_int8(buffer, AMF3_DATE);
        write_amf3_date(buffer, object);
      }
      else
      {
        write_c_int8(buffer, AMF3_OBJECT);
        write_amf3_object(buffer, object);
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
  write_amf3(buffer, object);
  return buffer_to_rstring(buffer);
}

void Init_AMF3Serializer() {
  rb_cRubyAMF_Ext_AMF3Serializer = rb_define_class_under(rb_mRubyAMF_Ext, "AMF3Serializer", rb_cObject);
  rb_define_method(rb_cRubyAMF_Ext_AMF3Serializer, "serialize", t_serialize, 1);
}