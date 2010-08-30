
#include <math.h>
#include "ruby_amf_core.h"
#include "IOReadBuffer.h"
#include "AMFConstants.h"
#include "AMFCache.h"

VALUE rb_cRubyAMF_Ext_AMF3Deserializer = Qnil;

VALUE rb_read_amf3(load_context_t* context);
static VALUE t_deserialize(VALUE self, VALUE string);

VALUE rb_read_amf3_number(load_context_t* context)
{
  double num = c_read_double(context);
  return isnan(num) ? Qnil : rb_float_new(num);
}

int8_t is_amf3_reference(uint32_t type)
{
  return (type & 0x01) == 0;
}

int32_t c_read_amf3_integer(load_context_t* context)
{
  int32_t  result = 0;
  u_char    b = 0;
  char      n = 0;
  
  for (; n < 4; n++) {
    b = read_byte(context);
    
    if (n < 3) {
      result = result << 7;
      result = result | (b & 0x7F);
      if (!(b & 0x80)) break;
    } else {
      result = result << 8;
      result = result | b;
    }
  }
  
  if (result > MAX_AMF3_INTEGER) {
    result -= (1 << 29);
  }
  
  return result;
}

VALUE rb_read_amf3_integer(load_context_t* context)
{
  return INT2NUM(c_read_amf3_integer(context));
}

VALUE rb_read_amf3_string(load_context_t* context)
{
  int32_t header = c_read_amf3_integer(context);
  
  if (is_amf3_reference(header)) {
    return amf_cache_get_string(context->amf_cache, (header >> 1));
  } else {
    int32_t len = (header >> 1);
    VALUE string = rb_str_new((char*)read_bytes(context, (size_t)len), len);
    if(len > 0) {
      amf_cache_add_string(context->amf_cache, string);
    }
    return string;
  }
}

VALUE rb_read_amf3_date(load_context_t* context)
{
  int32_t type = c_read_amf3_integer(context);

  if (is_amf3_reference(type)) {
    return amf_cache_get_obj(context->amf_cache, (type >> 1));
  }

  double milliseconds = c_read_double(context);
  long seconds      = (milliseconds / 1000.0);
  time_t microseconds = ((milliseconds / 1000.0) - (double)seconds) * (1000.0 * 1000.0);
  
  VALUE object = Qnil;
  if(0) { // future support for DateTime
    object = rb_datetime_new(seconds);
  } else {
    object = rb_time_new(seconds, microseconds);
  }
  
  amf_cache_add_obj(context->amf_cache, object);
  return object;
}

VALUE rb_read_amf3_array(load_context_t* context)
{
  int32_t type = c_read_amf3_integer(context);
  
  if (is_amf3_reference(type)) {
    return amf_cache_get_obj(context->amf_cache, (type >> 1));
  }
  
  int32_t len = (type >> 1);
  VALUE key, value;
  key = rb_read_amf3_string(context);
  if ((len >= 0) && (RSTRING_LEN(key) == 0)) {
    // strict array
    VALUE object = rb_ary_new();
    int32_t i = 0;
    for (;i<len;i++) {
      rb_ary_push(object, rb_read_amf3(context));
    }
    
    amf_cache_add_obj(context->amf_cache, object);
    return object;
  } else {
    // assoc array / hash
    VALUE object = rb_hash_new();
    while (1) {
      value = rb_read_amf3(context);
      rb_hash_aset(object, key, value);
      key = rb_read_amf3_string(context);
      if (RSTRING_LEN(key) == 0) { break; }
    }

    amf_cache_add_obj(context->amf_cache, object);
    return object;
  }
}

VALUE rb_read_amf3_object(load_context_t* context)
{
  int32_t i,type = c_read_amf3_integer(context);
  if (is_amf3_reference(type)) {
    return amf_cache_get_obj(context->amf_cache, (type >> 1));
  }
  
  VALUE traits             = Qnil;
  VALUE class_name         = Qnil;
  int32_t attribute_count  = 0;
  uint8_t externalizable   = 0;
  uint8_t dynamic          = 0;
  VALUE members            = Qnil;
  
  int32_t class_type = type >> 1;
  if (is_amf3_reference(class_type))
  {
    traits  = amf_cache_get_trait(context->amf_cache, (class_type >> 1));
    class_name       = rb_hash_aref(traits, rb_str_new2("class_name"));
    members          = rb_hash_aref(traits, rb_str_new2("members"));
    externalizable   = rb_hash_aref(traits, rb_str_new2("externalizable")) == Qtrue;
    dynamic          = rb_hash_aref(traits, rb_str_new2("dynamic"))        == Qtrue;
    attribute_count  = RARRAY_LEN(members);
  }
  else
  {
    traits           = rb_hash_new();
    class_name       = rb_read_amf3_string(context);
    externalizable   = ((class_type & 0x02) != 0);
    dynamic          = ((class_type & 0x04) != 0);
    attribute_count  = (class_type >> 3);
    members          = rb_ary_new();
    
    VALUE key = Qnil;
    for(i=0; i<attribute_count; i++) {
      key = rb_read_amf3_string(context);
      // key = rb_funcall(key, rb_intern("underscore"), 0);
      rb_ary_push(members, key);
    }
    
    rb_hash_aset(traits, rb_str_new2("class_name"),    class_name);
    rb_hash_aset(traits, rb_str_new2("members"),       members);
    rb_hash_aset(traits, rb_str_new2("externalizable"),(externalizable ? Qtrue : Qfalse));
    rb_hash_aset(traits, rb_str_new2("dynamic"),       (dynamic        ? Qtrue : Qfalse));
    
    amf_cache_add_trait(context->amf_cache, traits);
  }
  
  VALUE object = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("ruby_object_for"), 1, class_name);
  
  if (externalizable)
  {
    rb_funcall(object, rb_intern("externalized_data"), 1, rb_read_amf3(context));
  }
  else
  {
    VALUE props         = rb_hash_new();
    VALUE dynamic_props = Qnil;

    VALUE key = Qnil;
    for (i=0; i<RARRAY_LEN(members); i++) {
      key = rb_ary_entry(members, i);
      rb_hash_aset(props, key, rb_read_amf3(context));
    }
    
    if (dynamic)
    {
      dynamic_props = rb_hash_new();
      while (peek_byte(context) != 0x01) {
        key = rb_read_amf3_string(context);
        // key = rb_funcall(key, rb_intern("underscore"), 0);
        rb_hash_aset(dynamic_props, key, rb_read_amf3(context));
      }
      read_byte(context);
    }
    
    rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("populate_ruby_object"), 3, object, props, dynamic_props);
  }

  amf_cache_add_obj(context->amf_cache, object);
  return object;
}

VALUE rb_read_amf3_xml(load_context_t* context)
{
  int32_t type = c_read_amf3_integer(context);
  
  if (is_amf3_reference(type)) {
    return amf_cache_get_obj(context->amf_cache, (type >> 1));
  }
  
  int32_t len = (type >> 1);
  VALUE object = rb_str_new((char*)read_bytes(context, (size_t)len), len);
  if(len > 0) {
    amf_cache_add_obj(context->amf_cache, object);
  }
  return object;
}

VALUE rb_read_amf3_byte_array(load_context_t* context)
{
  int32_t type = c_read_amf3_integer(context);
  if (is_amf3_reference(type)) {
    return amf_cache_get_obj(context->amf_cache, (type >> 1));
  }
  
  int32_t len = (type >> 1);
  VALUE object = rb_str_new((char*)read_bytes(context, (size_t)len), len);
  if(len > 0) {
    amf_cache_add_obj(context->amf_cache, object);
  }
  return object;
}

VALUE rb_read_amf3(load_context_t* context)
{
  uint8_t type = c_read_word8(context);
  
  switch (type) {
    case AMF3_UNDEFINED:  return Qnil;
    case AMF3_NULL:       return Qnil;
    case AMF3_FALSE:      return Qfalse;
    case AMF3_TRUE:       return Qtrue;
    case AMF3_INTEGER:    return rb_read_amf3_integer(context);
    case AMF3_DOUBLE:     return rb_read_amf3_number(context);  //read standard AMF0 number
    case AMF3_STRING:     return rb_read_amf3_string(context);
    case AMF3_XML_DOC:    rb_raise(rb_eRuntimeError, "unsupported type: XMLDocument");
    case AMF3_DATE:       return rb_read_amf3_date(context);
    case AMF3_ARRAY:      return rb_read_amf3_array(context);
    case AMF3_OBJECT:     return rb_read_amf3_object(context);
    case AMF3_XML:        return rb_read_amf3_xml(context);
    case AMF3_BYTE_ARRAY: return rb_read_amf3_byte_array(context);
   }
   
   rb_raise(rb_eRuntimeError, "parser error");
}

static VALUE t_deserialize(VALUE self, VALUE string)
{
  load_context_t * context = context_new(string);
  VALUE output = rb_read_amf3(context);
  context_free(context);
  return output;
}

void Init_AMF3Deserializer() {
  rb_cRubyAMF_Ext_AMF3Deserializer = rb_define_class_under(rb_mRubyAMF_Ext, "AMF3Deserializer", rb_cObject);
  rb_define_method(rb_cRubyAMF_Ext_AMF3Deserializer, "deserialize", t_deserialize, 1);
}
