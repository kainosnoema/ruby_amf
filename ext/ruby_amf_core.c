#include "ruby.h"

VALUE rb_mRubyAMF = Qnil;
VALUE rb_mRubyAMF_Ext = Qnil;
VALUE rb_cRubyAMF_ClassMapping = Qnil;

VALUE rb_cDate = Qnil;
VALUE rb_cDateTime = Qnil;

static char rb_datetime_buffer[16];

void Init_ruby_amf_core() {
  rb_mRubyAMF   = rb_define_module("RubyAMF");
  rb_mRubyAMF_Ext = rb_define_module_under(rb_mRubyAMF, "Ext");
  rb_cRubyAMF_ClassMapping = rb_const_get(rb_mRubyAMF, rb_intern("ClassMapping"));
  
  rb_require("date");
  rb_require("rubygems");
  rb_funcall(rb_mKernel, rb_intern("require"), 1, rb_str_new2("active_support"));
  
  // initialize required type classes
  rb_cDate        = rb_const_get(rb_cObject, rb_intern("Date"));
  rb_cDateTime    = rb_const_get(rb_cObject, rb_intern("DateTime"));
}

VALUE rb_datetime_new(long seconds)
{
  sprintf(rb_datetime_buffer, "%li", seconds);
  return rb_funcall(rb_cDateTime, rb_intern("strptime"), 2, rb_str_new2((char *)&rb_datetime_buffer), rb_str_new2("%s"));
}

u_int rb_is_a(VALUE obj, VALUE klass)
{
  // need to use functions for classes that override this method
  return rb_funcall(obj, rb_intern("is_a?"), 1, klass) == Qtrue;
}