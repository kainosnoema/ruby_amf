
#ifndef __RUBY_AMF_CORE__
#define __RUBY_AMF_CORE__

#include <ruby.h>

extern VALUE rb_mRubyAMF;
extern VALUE rb_mRubyAMF_Ext;
extern VALUE rb_cRubyAMF_ClassMapping;
extern VALUE rb_cRubyAMF_Remoting_Envelope;
extern VALUE rb_cRubyAMF_Remoting_Header;
extern VALUE rb_cRubyAMF_Remoting_Body;

extern VALUE rb_cDate;
extern VALUE rb_cDateTime;
extern VALUE rb_cActiveRecordBase;

void Init_ruby_amf_core();

VALUE rb_datetime_new(long seconds);
u_int rb_is_a(VALUE obj, VALUE klass);
u_int rb_instance_of(VALUE obj, VALUE klass);

#endif