
#include <ruby.h>
#include "AMFCache.h"

/**
 *    Write buffer
 */
 
amf_cache_t* amf_cache_new(void)
{
  amf_cache_t * amf_cache = malloc(sizeof(amf_cache_t));
  
  // delay hash allocation for performance
  amf_cache->strings       = Qnil;
  amf_cache->strings_index = 0;
  amf_cache->objects       = Qnil;
  amf_cache->objects_index = 0;
  amf_cache->traits        = Qnil;
  amf_cache->traits_index  = 0;
  
  // AMF0 only
  amf_cache->refs        = Qnil;
  amf_cache->refs_index  = 0;
  
  return amf_cache;
}

inline int amf_cache_free(amf_cache_t* cache) {
    if (cache == NULL)
    {
        return 1;
    }
    rb_gc_unregister_address(&cache->objects);
    rb_gc_unregister_address(&cache->strings);
    rb_gc_unregister_address(&cache->traits);
    rb_gc_unregister_address(&cache->refs);
    free(cache);
    return 0;
}

inline void amf_cache_init_objects(amf_cache_t* cache)
{
  if(cache->objects == Qnil)
  {
    cache->objects = rb_hash_new();
    rb_gc_register_address(&cache->objects); // prevents garbage collection
  }
}

inline void amf_cache_init_strings(amf_cache_t* cache)
{
  if(cache->strings == Qnil) {
    cache->strings = rb_hash_new();
    rb_gc_register_address(&cache->strings);
  }
}

inline void amf_cache_init_traits(amf_cache_t* cache)
{
  if(cache->traits == Qnil) {
    cache->traits = rb_hash_new();
    rb_gc_register_address(&cache->traits);
  }
}

inline void amf_cache_init_refs(amf_cache_t* cache)
{
  if(cache->refs == Qnil) {
    cache->refs = rb_hash_new();
    rb_gc_register_address(&cache->refs);
  }
}

/*
 * AMF3 Serialization functions, references indexed by object
 */

inline void amf_cache_add_objref(amf_cache_t* cache, VALUE obj)
{
  amf_cache_init_objects(cache);
  rb_hash_aset(cache->objects, rb_obj_id(obj), cache->objects_index);
  cache->objects_index++;
}

inline VALUE amf_cache_get_objref(amf_cache_t* cache, VALUE obj)
{
  if(cache->objects == Qnil)
    return Qnil; // no need to check
  return rb_hash_aref(cache->objects, rb_obj_id(obj));
}

inline void amf_cache_add_stringref(amf_cache_t* cache, VALUE obj)
{
  amf_cache_init_strings(cache);
  rb_hash_aset(cache->strings, obj, cache->strings_index);
  cache->strings_index++;
}

inline VALUE amf_cache_get_stringref(amf_cache_t* cache, VALUE obj)
{
  if(cache->strings == Qnil)
    return Qnil; // no need to check
  return rb_hash_aref(cache->strings, obj);
}

/*
 * AMF3 Deserialization functions, objects indexed by reference
 */

inline void amf_cache_add_obj(amf_cache_t* cache, VALUE obj)
{
  amf_cache_init_objects(cache);
  rb_hash_aset(cache->objects, cache->objects_index, obj);
  cache->objects_index++;
}

inline VALUE amf_cache_get_obj(amf_cache_t* cache, VALUE ref)
{
  if(cache->objects == Qnil)
    return Qnil; // no need to check
  return rb_hash_aref(cache->objects, ref);
}

inline void amf_cache_add_string(amf_cache_t* cache, VALUE obj)
{
  amf_cache_init_strings(cache);
  rb_hash_aset(cache->strings, cache->strings_index, obj);
  cache->strings_index++;
}

inline VALUE amf_cache_get_string(amf_cache_t* cache, VALUE ref)
{
  if(cache->strings == Qnil)
    return Qnil; // no need to check
  return rb_hash_aref(cache->strings, ref);
}

inline void amf_cache_add_trait(amf_cache_t* cache, VALUE obj)
{
  amf_cache_init_traits(cache);
  rb_hash_aset(cache->traits, cache->traits_index, obj);
  cache->traits_index++;
}

inline VALUE amf_cache_get_trait(amf_cache_t* cache, VALUE ref)
{
  if(cache->objects == Qnil)
    return Qnil; // no need to check
  return rb_hash_aref(cache->traits, ref);
}

/*
 * AMF0 Deserialization functions, objects indexed by reference
 */
 
inline void amf_cache_add_amf0obj(amf_cache_t* cache, VALUE obj)
{
  amf_cache_init_refs(cache);
  rb_hash_aset(cache->refs, cache->objects_index, obj);
  cache->objects_index++;
}

inline VALUE amf_cache_get_amf0obj(amf_cache_t* cache, VALUE ref)
{
  if(cache->refs == Qnil)
   return Qnil; // no need to check
  return rb_hash_aref(cache->refs, ref);
}