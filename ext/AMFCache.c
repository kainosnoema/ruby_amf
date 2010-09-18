
#include <ruby.h>
#include "AMFCache.h"

/**
 *    Write buffer
 */
 
amf_cache_t* amf_cache_new(void)
{
  amf_cache_t * amf_cache = malloc(sizeof(amf_cache_t));
  amf_cache_reset(amf_cache); // allocates and registers hashes with gc
  return amf_cache;
}

inline int amf_cache_free(amf_cache_t* cache) {
    if (cache == NULL)
    {
        return 1;
    }
    rb_gc_unregister_address(&cache->strings);
    rb_gc_unregister_address(&cache->objects);
    rb_gc_unregister_address(&cache->traits);
    rb_gc_unregister_address(&cache->refs);
    free(cache);
    return 0;
}

inline void amf_cache_reset(amf_cache_t* cache) {
  rb_gc_unregister_address(&cache->strings);
  cache->strings = rb_hash_new();
  rb_gc_register_address(&cache->strings);
  cache->strings_index = 0;

  rb_gc_unregister_address(&cache->objects);
  cache->objects = rb_hash_new();
  rb_gc_register_address(&cache->objects);
  cache->objects_index = 0;

  rb_gc_unregister_address(&cache->traits);
  cache->traits = rb_hash_new();
  rb_gc_register_address(&cache->traits);
  cache->traits_index = 0;

  rb_gc_unregister_address(&cache->refs);
  cache->refs = rb_hash_new();
  rb_gc_register_address(&cache->refs);
  cache->refs_index = 0;
}

/*
 * AMF3 Serialization functions, references indexed by object
 */

inline void amf_cache_add_objref(amf_cache_t* cache, VALUE obj)
{
  rb_hash_aset(cache->objects, rb_obj_id(obj), LONG2FIX(cache->objects_index));
  cache->objects_index++;
}

inline VALUE amf_cache_get_objref(amf_cache_t* cache, VALUE obj)
{
  return rb_hash_aref(cache->objects, rb_obj_id(obj));
}

inline void amf_cache_add_stringref(amf_cache_t* cache, VALUE obj)
{
  rb_hash_aset(cache->strings, obj, LONG2FIX(cache->strings_index));
  cache->strings_index++;
}

inline VALUE amf_cache_get_stringref(amf_cache_t* cache, VALUE obj)
{
  return rb_hash_aref(cache->strings, obj);
}

inline void amf_cache_add_traitref(amf_cache_t* cache, VALUE obj)
{
  rb_hash_aset(cache->traits, obj, LONG2FIX(cache->traits_index));
  cache->traits_index++;
}

inline VALUE amf_cache_get_traitref(amf_cache_t* cache, VALUE obj)
{
  return rb_hash_aref(cache->traits, obj);
}

/*
 * AMF3 Deserialization functions, objects indexed by reference
 */

inline void amf_cache_add_obj(amf_cache_t* cache, VALUE obj)
{
  rb_hash_aset(cache->objects, LONG2FIX(cache->objects_index), obj);
  cache->objects_index++;
}

inline VALUE amf_cache_get_obj(amf_cache_t* cache, int32_t ref)
{
  return rb_hash_aref(cache->objects, LONG2FIX(ref));
}

inline void amf_cache_add_string(amf_cache_t* cache, VALUE obj)
{
  rb_hash_aset(cache->strings, LONG2FIX(cache->strings_index), obj);
  cache->strings_index++;
}

inline VALUE amf_cache_get_string(amf_cache_t* cache, int32_t ref)
{
  return rb_hash_aref(cache->strings, LONG2FIX(ref));
}

inline void amf_cache_add_trait(amf_cache_t* cache, VALUE obj)
{
  rb_hash_aset(cache->traits, LONG2FIX(cache->traits_index), obj);
  cache->traits_index++;
}

inline VALUE amf_cache_get_trait(amf_cache_t* cache, int32_t ref)
{
  return rb_hash_aref(cache->traits, LONG2FIX(ref));
}

/*
 * AMF0 Deserialization functions, objects indexed by reference
 */
 
inline void amf_cache_add_amf0obj(amf_cache_t* cache, VALUE obj)
{
  rb_hash_aset(cache->refs, LONG2FIX(cache->objects_index), obj);
  cache->objects_index++;
}

inline VALUE amf_cache_get_amf0obj(amf_cache_t* cache, VALUE ref)
{
  return rb_hash_aref(cache->refs, LONG2FIX(ref));
}