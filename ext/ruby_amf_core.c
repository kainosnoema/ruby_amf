#include "ruby.h"

VALUE rb_mRubyAMF = Qnil;
VALUE rb_mRubyAMF_Ext = Qnil;
VALUE rb_cRubyAMF_ClassMapping = Qnil;
VALUE rb_cRubyAMF_Remoting_Envelope = Qnil;
VALUE rb_cRubyAMF_Remoting_Header = Qnil;
VALUE rb_cRubyAMF_Remoting_Body = Qnil;

VALUE rb_cDate = Qnil;
VALUE rb_cDateTime = Qnil;
VALUE rb_cActiveRecordBase = Qnil;

static char rb_datetime_buffer[16];

void Init_ruby_amf_core() {
  rb_mRubyAMF   = rb_define_module("RubyAMF");
  rb_mRubyAMF_Ext = rb_define_module_under(rb_mRubyAMF, "Ext");
  rb_cRubyAMF_ClassMapping = rb_const_get(rb_mRubyAMF, rb_intern("ClassMapping"));
  
  VALUE rb_mRubyAMF_Remoting = rb_const_get(rb_mRubyAMF, rb_intern("Remoting"));
  rb_cRubyAMF_Remoting_Envelope = rb_const_get(rb_mRubyAMF_Remoting, rb_intern("Envelope"));
  rb_cRubyAMF_Remoting_Header = rb_const_get(rb_mRubyAMF_Remoting, rb_intern("Header"));
  rb_cRubyAMF_Remoting_Body = rb_const_get(rb_mRubyAMF_Remoting, rb_intern("Body"));
  
  rb_require("date");
  rb_require("rubygems");
  rb_funcall(rb_mKernel, rb_intern("require"), 1, rb_str_new2("active_support"));
  rb_funcall(rb_mKernel, rb_intern("require"), 1, rb_str_new2("active_record"));
  
  // initialize required type classes
  rb_cDate        = rb_const_get(rb_cObject, rb_intern("Date"));
  rb_cDateTime    = rb_const_get(rb_cObject, rb_intern("DateTime"));
  // rb_cActiveRecordBase    = rb_const_get(rb_const_get(rb_cObject, rb_intern("ActiveRecord")), rb_intern("Base"));
}

VALUE rb_datetime_new(long seconds)
{
  sprintf(rb_datetime_buffer, "%li", seconds);
  return rb_funcall(rb_cDateTime, rb_intern("strptime"), 2, rb_str_new2((char *)&rb_datetime_buffer), rb_str_new2("%s"));
}

u_int rb_is_a(VALUE obj, VALUE klass)
{
  return rb_obj_is_kind_of(obj, klass) == Qtrue;
}

u_int rb_instance_of(VALUE obj, VALUE klass)
{
  return rb_obj_is_instance_of(obj, klass) == Qtrue;
}