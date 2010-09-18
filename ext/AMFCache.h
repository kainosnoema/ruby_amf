#ifndef __SERIALIZER_CACHE__
#define __SERIALIZER_CACHE__

#include <ruby.h>

typedef struct amf_cache {
  VALUE strings;
  VALUE strings_index;

  VALUE objects;
  uint32_t objects_index;

  VALUE traits;
  uint32_t traits_index;
  
  // AMF0 only
  VALUE refs;
  uint32_t refs_index;
} amf_cache_t;

amf_cache_t * amf_cache_new(void);

inline int amf_cache_free(amf_cache_t* cache);
inline void amf_cache_reset(amf_cache_t* cache);

/*
 * AMF3 Serialization functions, references indexed by object
 */

inline void amf_cache_add_objref(amf_cache_t* cache, VALUE obj);

inline VALUE amf_cache_get_objref(amf_cache_t* cache, VALUE obj);

inline void amf_cache_add_stringref(amf_cache_t* cache, VALUE obj);

inline VALUE amf_cache_get_stringref(amf_cache_t* cache, VALUE obj);

inline void amf_cache_add_traitref(amf_cache_t* cache, VALUE obj);

inline VALUE amf_cache_get_traitref(amf_cache_t* cache, VALUE obj);

/*
 * AMF3 Deserialization functions, objects indexed by reference
 */

inline void amf_cache_add_obj(amf_cache_t* cache, VALUE obj);

inline VALUE amf_cache_get_obj(amf_cache_t* cache, int32_t ref);

inline void amf_cache_add_string(amf_cache_t* cache, VALUE obj);

inline VALUE amf_cache_get_string(amf_cache_t* cache, int32_t ref);

inline void amf_cache_add_trait(amf_cache_t* cache, VALUE obj);

inline VALUE amf_cache_get_trait(amf_cache_t* cache, int32_t ref);

/*
 * AMF0 Deserialization functions, objects indexed by reference
 */

inline void amf_cache_add_amf0obj(amf_cache_t* cache, VALUE obj);

inline VALUE amf_cache_get_amf0obj(amf_cache_t* cache, VALUE ref);

#endif

