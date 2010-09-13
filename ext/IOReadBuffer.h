
#ifndef READ_BUFFER_H
#define READ_BUFFER_H

#include <ruby.h>
#include "AMFCache.h"

typedef struct {
  u_char * buffer;
  u_char * cursor;
  u_char * buffer_end;

  amf_cache_t * amf_cache;
  
  // VALUE string_cache;
  // VALUE object_cache;
  // VALUE trait_cache;
  // 
  // // AMF0 only
  // VALUE ref_cache;
} load_context_t;

inline load_context_t * context_new(VALUE string);

inline int context_free(load_context_t* context);

inline u_char peek_byte(load_context_t* context);

inline u_char read_byte(load_context_t* context);

inline u_char* read_bytes(load_context_t* context, uint32_t len);

/**
 *    Binary read functions
 */

inline uint8_t c_read_word8(load_context_t* context);

inline int8_t c_read_int8(load_context_t* context);

inline uint16_t c_read_word16_network(load_context_t* context);

inline int16_t c_read_int16_network(load_context_t* context);

inline uint32_t c_read_word32_network(load_context_t* context);

inline double c_read_double(load_context_t* context);

#endif