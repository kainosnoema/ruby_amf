// uint32_t ref = (uint32_t)amf_cache_get_objref(buffer->amf_cache, rval);
// if(ref != Qnil)
//   write_amf3_reference(buffer, ref);
// else
// {
//   amf_cache_add_objref(buffer->amf_cache, rval);
// 
//   VALUE traits             = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_traits_for"), 1, rval);
//   rb_gc_register_address(&traits);
//   
//   VALUE class_name         = rb_hash_aref(traits, ID2SYM(rb_intern("class_name")));
//   VALUE members            = rb_hash_aref(traits, ID2SYM(rb_intern("members")));
//   uint8_t externalizable   = rb_hash_aref(traits, ID2SYM(rb_intern("externalizable"))) == Qtrue;
//   uint8_t dynamic          = rb_hash_aref(traits, ID2SYM(rb_intern("dynamic")))        == Qtrue;
//   uint32_t member_count    = (uint32_t)RARRAY_LEN(members);
// 
//   uint32_t class_ref = (uint32_t)amf_cache_get_traitref(buffer->amf_cache, class_name);
//   if(class_ref != Qnil)
//   {
//     write_c_integer(buffer, class_ref << 2 | 0x01);
//   }
//   else
//   {
//     if(class_name != Qnil)
//     {
//       amf_cache_add_traitref(buffer->amf_cache, class_name);
//     }
// 
//     // write header
//     uint32_t header = 0x03;
//     if(dynamic) {
//       header = header | 0x02 << 2;
//     }
//     if(externalizable) {
//       header = header | 0x01 << 2;
//     }
//     header = header | member_count << 4;
//     write_c_integer(buffer, header);
//   
//     // write class_name
//     write_amf3_string(buffer, class_name);
//   
//     // write out members
//     uint32_t i;
//     for(i=0; i<member_count; i++)
//     {
//       write_amf3_string(buffer, RARRAY_PTR(members)[i]);
//     }
//   }
// 
//   if(externalizable)
//   {
//     // write_amf3(buffer, rb_funcall(rval, rb_intern("externalized_data"), 0));
//     // return;
//   }
//   
//   // write out sealed properties
//   VALUE properties = rb_funcall(rb_cRubyAMF_ClassMapping, rb_intern("as_properties_for"), 1, rval);
//   uint32_t i;
//   for(i=0; i<member_count; i++)
//   {
//     VALUE member = RARRAY_PTR(members)[i];
//     write_amf3(buffer, rb_funcall(properties, rb_intern("delete"), 1, member));
//   }
// 
//   // write out remaining properties if dynamic
//   if(dynamic)
//   {
//     rb_block_call(properties, rb_intern("each_pair"), 0, 0, write_amf3_hash_pair, (VALUE) buffer);
//     write_c_int8(buffer, AMF3_CLOSE_DYNAMIC_OBJECT);
//   }
//   
//   rb_gc_unregister_address(&traits);
// }