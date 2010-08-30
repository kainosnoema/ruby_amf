
#include "ruby_amf_core.h"
#include "IOReadBuffer.h"
#include "AMFConstants.h"
#include "AMF3Deserializer.h"

#define bool uint8_t

VALUE rb_cRubyAMF_Ext_AMF0Deserializer = Qnil;

VALUE rb_read_amf0(load_context_t* context, uint8_t type);
static VALUE t_deserialize(VALUE self, VALUE string);

VALUE rb_read_boolean(load_context_t* context)
{
  return ((c_read_int8(context) != 0) ? Qtrue : Qfalse);
}

VALUE rb_read_amf0_number(load_context_t* context)
{
  return rb_float_new(c_read_double(context));
}

VALUE rb_read_utf_string(load_context_t* context)
{
  uint16_t len = (uint16_t)c_read_word16_network(context);
  return rb_str_new((char*)read_bytes(context, (size_t)len), len);
}

VALUE rb_read_utf_long_string(load_context_t* context)
{
  uint32_t len = (uint32_t)c_read_word32_network(context);
  return rb_str_new((char*)read_bytes(context, (size_t)len), len);
}

VALUE rb_read_amf0_reference(load_context_t* context)
{
  uint16_t ref = c_read_word16_network(context);
  return amf_cache_get_amf0obj(context->amf_cache, ref);
}

VALUE rb_read_amf0_array(load_context_t* context)
{
  uint32_t i, len = c_read_word32_network(context);

  VALUE object = rb_ary_new();

  for (i=0;i<len;i++) {
    uint8_t type = c_read_word8(context);
    rb_ary_push(object, rb_read_amf0(context, type));
  }

  amf_cache_add_amf0obj(context->amf_cache, object);
  return object;
}

VALUE rb_read_amf0_hash(load_context_t* context)
{
  c_read_word32_network(context); //length
  
  VALUE object = Qnil;
  
  VALUE   key = rb_read_utf_string(context);
  
  uint8_t type = c_read_word8(context);
  if (type == AMF0_OBJECT_END) {
    return rb_ary_new();
  }
  
  // We need to figure out whether this is a real hash, or whether some stupid serializer gave up
  if (rb_str_cmp( rb_big2str(rb_str_to_inum(key, 10, Qfalse),10),  key) == 0) {
    // array
    object = rb_ary_new();
    
    rb_ary_store(object, NUM2LONG(rb_str_to_inum(key, 10, Qfalse)), rb_read_amf0(context, type));
    while (1) {
      VALUE key = rb_str_to_inum(rb_read_utf_string(context), 10, Qfalse);
      uint8_t type = c_read_word8(context);
      if (type == AMF0_OBJECT_END) { break; }
      rb_ary_store(object, NUM2LONG(key), rb_read_amf0(context, type));
    }
    
    amf_cache_add_amf0obj(context->amf_cache, object);
    return object;
  } else {
    // hash
    object = rb_hash_new();
    rb_hash_aset(object, key, rb_read_amf0(context, type));

    while (1) {
      VALUE key = rb_read_utf_string(context);
      
      uint8_t type = c_read_word8(context);
      if (type == AMF0_OBJECT_END) { break; }
      rb_hash_aset(object, key, rb_read_amf0(context, type));
    }
    
    amf_cache_add_amf0obj(context->amf_cache, object);
    return object;
  }
}

VALUE rb_read_amf0_date(load_context_t* context)
{
  double seconds_f = c_read_double(context) / 1000.0;
  c_read_word16_network(context); // timezone
  
  time_t seconds      = seconds_f;
  time_t microseconds = (seconds_f - (double)seconds) * (1000.0 * 1000.0);
  
  return rb_time_new(seconds, microseconds);
}

VALUE rb_read_amf0_xml(load_context_t* context)
{
  return rb_read_utf_long_string(context);
}

VALUE rb_read_amf0_object(load_context_t* context, bool add_to_ref_cache)
{
  // ID underscore_id = (ID)0;
  // if (underscore_id == (ID)0) {
  //   underscore_id = rb_intern("underscore");
  // }
  
  VALUE object = rb_hash_new();
  
  while (1) {
    VALUE key = rb_read_utf_string(context);
    uint8_t type = c_read_word8(context);
    if (type == AMF0_OBJECT_END) { break; }
    
    //key = rb_funcall(key, underscore_id, 0);
    key = rb_str_intern(key);
    rb_hash_aset(object, key, rb_read_amf0(context, type));
  }
  
  if (add_to_ref_cache) {
    amf_cache_add_amf0obj(context->amf_cache, object);
  }
  
  return object;
}

VALUE rb_read_amf0_typed_object(load_context_t* context)
{
  static VALUE rb_amf_cClassMapper         = Qnil;
  static ID    rb_amf_get_ruby_obj_id      = (ID)0;
  static ID    rb_amf_populate_ruby_obj_id = (ID)0;
  if (rb_amf_cClassMapper == Qnil) {
    rb_amf_cClassMapper         = rb_const_get(rb_const_get(rb_cObject, rb_intern("AMF")), rb_intern("ClassMapper"));
    rb_amf_get_ruby_obj_id      = rb_intern("get_ruby_obj");
    rb_amf_populate_ruby_obj_id = rb_intern("populate_ruby_obj");
  }
  
  VALUE klass_name = rb_read_utf_string(context);
  VALUE object     = rb_funcall(
    rb_amf_cClassMapper, rb_amf_get_ruby_obj_id, 1,
    klass_name);
  
  VALUE props  = rb_read_amf0_object(context, 0);
  rb_funcall(
    rb_amf_cClassMapper, rb_amf_populate_ruby_obj_id, 3,
    object, props, rb_hash_new());
  
  amf_cache_add_amf0obj(context->amf_cache, object);
  return object;
}

VALUE rb_read_amf0(load_context_t* context, uint8_t type)
{  
  switch (type) {
    case AMF0_AMF3_TYPE:    return rb_read_amf3(context);
    case AMF0_NUMBER:       return rb_read_amf0_number(context);
    case AMF0_BOOLEAN:      return rb_read_boolean(context);
    case AMF0_STRING:       return rb_read_utf_string(context);
    case AMF0_OBJECT:       return rb_read_amf0_object(context, 1);
    case AMF0_MOVIE_CLIP:   rb_raise(rb_eRuntimeError, "unsupported type: Movieclip");
    case AMF0_NULL:         return Qnil;
    case AMF0_UNDEFINED:    return Qnil;
    case AMF0_REFERENCE:    return rb_read_amf0_reference(context);
    case AMF0_HASH:         return rb_read_amf0_hash(context);
    case AMF0_STRICT_ARRAY: return rb_read_amf0_array(context);
    case AMF0_DATE:         return rb_read_amf0_date(context);
    case AMF0_LONG_STRING:  return rb_read_utf_long_string(context);
    case AMF0_UNSUPPORTED:  rb_raise(rb_eRuntimeError, "unsupported type");
    case AMF0_RECORDSET:    rb_raise(rb_eRuntimeError, "unsupported type: Recordset");
    case AMF0_XML:          return rb_read_amf0_xml(context);
    case AMF0_TYPED_OBJECT: return rb_read_amf0_typed_object(context);
  }
  
  rb_raise(rb_eRuntimeError, "parser error");
}

static VALUE t_deserialize(VALUE self, VALUE string)
{
  load_context_t * context = context_new(string);
  uint8_t type = c_read_word8(context);
  return rb_read_amf0(context, type);
}

void Init_AMF0Deserializer() {
  rb_cRubyAMF_Ext_AMF0Deserializer = rb_define_class_under(rb_mRubyAMF_Ext, "AMF0Deserializer", rb_cObject);
  rb_define_method(rb_cRubyAMF_Ext_AMF0Deserializer, "deserialize", t_deserialize, 1);
}
