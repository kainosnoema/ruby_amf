
#ifndef WRITE_BUFFER_H
#define WRITE_BUFFER_H

#include <ruby.h>
#include "AMFCache.h"

typedef struct buffer {
  u_char * buffer;
  u_char * cursor;
  u_int allocated;
  
  amf_cache_t * amf_cache;
  
} buffer_t;


inline buffer_t * buffer_new(void);

inline VALUE buffer_to_rstring(buffer_t* buffer);


inline int write_bytes(buffer_t* buffer, const u_char * bytes, uint32_t len);

inline void write_byte(buffer_t* buffer, const u_char * byte);

/*
 * Binary helper functions
 */
 
inline void write_c_word8(buffer_t* buffer, uint8_t ival);

inline void write_c_int8(buffer_t* buffer, int8_t ival);

inline void write_c_word16_network(buffer_t* buffer, uint16_t ival);

inline void write_c_int16_network(buffer_t* buffer, int16_t ival);

inline void write_c_word32_network(buffer_t* buffer, uint32_t ival);

inline void write_c_double(buffer_t* buffer, double dval);

#endif