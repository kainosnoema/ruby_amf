
#include "ruby_amf_core.h"
#include "IOReadBuffer.h"
#include "IOWriteBuffer.h"
#include "AMFConstants.h"
#include "AMF0Deserializer.h"
#include "AMF0Serializer.h"
#include "AMF3Serializer.h"
#include "AMFCache.h"

VALUE rb_cRubyAMF_Remoting_Envelope = Qnil;
VALUE rb_cRubyAMF_Remoting_Envelope_Header = Qnil;
VALUE rb_cRubyAMF_Remoting_Envelope_Body = Qnil;

static VALUE t_deserialize(VALUE self, VALUE string);
static VALUE t_serialize(VALUE self);

VALUE rb_read_message_data(load_context_t* context)
{
  c_read_word32_network(context);       // length of message, unused
  uint8_t type = c_read_word8(context); // usually an array
  VALUE output = rb_read_amf0(context, type);
  amf_cache_reset(context->amf_cache);  // reset cache indices for each message
  return output;
}

VALUE rb_read_amf_request(VALUE envelope, load_context_t* context)
{
  VALUE amf_version = INT2FIX(c_read_word16_network(context));
  
  VALUE headers = rb_ary_new();
  uint16_t i, header_count = c_read_word16_network(context);
  for (i=0; i<header_count; i++) {
    VALUE name = rb_read_utf_string(context);
    VALUE must_understand = rb_read_boolean(context);
    
    VALUE data = rb_read_message_data(context);
    
    rb_ary_push(headers, rb_funcall(rb_cRubyAMF_Remoting_Envelope_Header, rb_intern("new"), 3, name, must_understand, data));
  }
  
  VALUE bodies = rb_ary_new();
  uint16_t body_count = c_read_word16_network(context);
  for (i=0; i<body_count; i++) {
    VALUE target_uri = rb_read_utf_string(context);
    VALUE response_uri = rb_read_utf_string(context);
    
    VALUE data = rb_read_message_data(context);
    
    rb_ary_push(bodies, rb_funcall(rb_cRubyAMF_Remoting_Envelope_Body, rb_intern("new"), 3, target_uri, response_uri, data));
  }
  
  rb_iv_set(envelope, "@amf_version", amf_version);
  rb_iv_set(envelope, "@headers", headers);
  rb_iv_set(envelope, "@bodies", bodies);
  
  return Qtrue;
}

static VALUE t_deserialize(VALUE self, VALUE string)
{
  if(!rb_is_a(self, rb_cRubyAMF_Remoting_Envelope))
  {
    rb_raise(rb_eRuntimeError, "RubyAMF::Ext::AMFRemoting.deserialize() can only be \
                                called on a RubyAMF::Remoting::Envelope.");
  }
  
  load_context_t * context = context_new(string);
  VALUE output = rb_read_amf_request(self, context);
  context_free(context);
  return output;
}

void write_amf_request(buffer_t* buffer, VALUE envelope)
{
  VALUE amf_version = rb_iv_get(envelope, "@amf_version");
  VALUE headers = rb_iv_get(envelope, "@headers");
  VALUE bodies = rb_iv_get(envelope, "@bodies");
  
  write_c_word16_network(buffer, FIX2INT(amf_version));

  uint16_t i, header_count = FIX2INT(rb_funcall(headers, rb_intern("length"), 0));
  write_c_word16_network(buffer, header_count);
  for (i=0; i<header_count; i++) {
    VALUE header = RARRAY_PTR(headers)[i];

    write_utf_string(buffer, rb_iv_get(header, "@name"));
    write_boolean(buffer, rb_iv_get(header, "@must_understand"));
    
    write_c_word32_network(buffer, -1); // header length, set to maximum
    
    write_amf0(buffer, rb_iv_get(header, "@data"));
  }

  uint16_t body_count = FIX2INT(rb_funcall(bodies, rb_intern("length"), 0));
  write_c_word16_network(buffer, body_count);
  for (i=0; i<body_count; i++) {
    VALUE body = RARRAY_PTR(bodies)[i];

    write_utf_string(buffer, rb_iv_get(body, "@target_uri"));
    write_utf_string(buffer, rb_iv_get(body, "@response_uri"));
    
    write_c_word32_network(buffer, -1); // body length, set to maximum
    if(FIX2INT(amf_version) == 3)
      write_c_int8(buffer, AMF0_AMF3_TYPE); // switch to AMF3 format
      
    write_amf3(buffer, rb_iv_get(body, "@data"));
  }
}

static VALUE t_serialize(VALUE self)
{
  if(!rb_is_a(self, rb_cRubyAMF_Remoting_Envelope))
  {
    rb_raise(rb_eRuntimeError, "RubyAMF::Ext::AMFRemoting.serialize() can only be \
                                called on a RubyAMF::Remoting::Envelope.");
  }
  
  buffer_t * buffer = buffer_new();
  write_amf_request(buffer, self);
  return buffer_to_rstring(buffer);
}

void Init_AMFRemoting() {
  VALUE rb_mRubyAMF_Remoting = rb_const_get(rb_mRubyAMF, rb_intern("Remoting"));
  rb_cRubyAMF_Remoting_Envelope = rb_const_get(rb_mRubyAMF_Remoting, rb_intern("Envelope"));
  rb_cRubyAMF_Remoting_Envelope_Header = rb_const_get(rb_cRubyAMF_Remoting_Envelope, rb_intern("Header"));
  rb_cRubyAMF_Remoting_Envelope_Body = rb_const_get(rb_cRubyAMF_Remoting_Envelope, rb_intern("Body"));
  
  rb_define_method(rb_cRubyAMF_Remoting_Envelope, "deserialize", t_deserialize, 1);
  rb_define_method(rb_cRubyAMF_Remoting_Envelope, "serialize", t_serialize, 0);
}